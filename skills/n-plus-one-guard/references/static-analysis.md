# Static Analysis — Semgrep / ast-grep / ESLint (cross-language) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

**Polyglot**, **static-only** spoke: detects the `loop-of-calls` shape (lexical
DB/HTTP call inside a loop) without running the code. Runtime, tracing, and the
microservice N+1 (HTTP fan-out in production) live in `service-fanout.md` — cross over.
Static has a ceiling: it **won't** catch the false-cure of moving the call into a helper
called per item (only SQL fingerprinting / span-count catches that). Use it as a **cheap
CI gate**, not as proof of absence.

## Detect — runtime

Static has no fail-at-point. The guard that fires on the exact `file:line` of the lazy
access lives in the ORM spokes (`raiseload`, `strict_loading`, etc.) and the universal
trace-based fan-out detector is in `service-fanout.md`. The closest "runtime" here is the
**request-scoped call counter** that fails the request when the ceiling is exceeded:

```js
// counter.js — counts DB+HTTP per request; fails (and CI e2e) above the ceiling
const { AsyncLocalStorage } = require('node:async_hooks');
const als = new AsyncLocalStorage();
const countCalls = (req, res, next) => als.run({ n: 0 }, next);
const bump = () => { const s = als.getStore(); if (s) s.n++; };      // wrap db/http client
const guard = (res, max = 20) => { const s = als.getStore();
  if (s && s.n > max) { res.set('X-Query-Count', String(s.n)); throw new Error(`N+1: ${s.n} > ${max}`); } };
// app.use(countCalls); pool.query = (q,a) => (bump(), realQuery(q,a)); res.on('finish', () => guard(res));
```

## Detect — static / lint

**ast-grep** — DB/HTTP call inside any loop (AST-precise, polyglot). Put the
rule in `sgconfig.yml`'s `ruleDir`; `ast-grep scan` exits **nonzero** on `severity: error`:

```yaml
id: call-in-loop
language: TypeScript        # swap + pattern per ecosystem (requests.$M, axios.$M, $C.query)
severity: error
message: Network/DB call inside a loop — likely N+1; batch or DataLoader.
rule:
  pattern: $CLIENT.$M($$$)
  inside:
    any: [{kind: for_statement},{kind: for_in_statement},{kind: for_of_statement},{kind: while_statement}]
    stopBy: end
```

ast-grep **await-in-loop** (sequential JS/TS fan-out) — catches the `await` even without knowing the client:

```yaml
id: no-await-in-loop
language: TypeScript
severity: error
rule:
  pattern: await $_
  inside:
    any: [{kind: for_in_statement},{kind: for_of_statement},{kind: while_statement},{kind: do_statement}]
    stopBy: end
```

**Semgrep** — `patterns:` ANDs a `pattern-inside` (the loop, body `...`) with the inner
call. Focus `pattern-either` on real clients to cut noise. `semgrep scan --error`
→ exit 1 on any finding:

```yaml
rules:
  - id: http-call-in-loop
    languages: [python]
    severity: WARNING
    message: HTTP call inside loop — N+1 fan-out; use a batch endpoint.
    patterns:
      - pattern-inside: |
          for $X in ...:
            ...
      - pattern-not-inside: |          # allowlist: already batched/prefetched
          for $X in batched(...):
            ...
      - pattern-either:
          - pattern: requests.$M(...)
          - pattern: httpx.$M(...)
          - pattern: $SESSION.get(...)
```

ORM variant (DB N+1) — same shape, inner `pattern` is the accessor; combine with
`pattern-not-inside` to allow a queryset with `select_related`/`prefetch_related`:

```yaml
  - id: orm-query-in-loop
    languages: [python]
    severity: WARNING
    message: ORM query in loop — add select_related/prefetch_related.
    patterns:
      - pattern-inside: |
          for $X in $QS:
            ...
      - pattern-either:
          - pattern: $X.$REL.all()
          - pattern: $MODEL.objects.filter(...)
```

**ESLint core `no-await-in-loop`** (JS/TS, zero plugins) — catches serialized awaits;
`--max-warnings 0` fails CI. **Doesn't** catch `.map(async)`/`Promise.all` (cover those with ast-grep):

```js
// eslint.config.js (flat)
export default [{ rules: { 'no-await-in-loop': 'error' } }];
// CI: eslint . --max-warnings 0
```

**SonarQube** — there's no **single** cross-language N+1 rule; curate per-language perf
rules in the Quality Profile (`sonar-java`/`sonar-dotnet` have "query/method in loop";
S2629 logging-in-loop) and pin them to the **Quality Gate** to fail the pipeline:

```properties
# sonar-project.properties
sonar.qualitygate.wait=true   # CI step blocks on the gate
# Quality Gate (Sonar way): 'Issues on New Code' = 0; scanner exits nonzero when the gate fails
```

## Fix — eager idioms by cardinality

The universal fix is to **hoist the per-item call into ONE batch/`IN (...)` call + in-memory
group-by** — works for both SQL and HTTP, false-cure-proof. Per-ORM eager-load detail lives
in the language spokes; here's the transport-agnostic idiom:

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1·FK | Per-request memoization (kills **duplicate** fan-out, not just sequential) | `const getUser = id => cache.has(id) ? cache.get(id) : cache.set(id, fetchUser(id)).get(id);` |
| 1:N | Hoist to 1 batch endpoint + in-memory `groupBy` (not JOIN) | `const items = await api.post('/items:batchGet',{orderIds}); orders.forEach(o=>o.items=byOrder[o.id]??[]);` |
| M:N | DataLoader: 1 loader **per request**, batch fn takes `keys[]`, returns in order | `const l = new DataLoader(ids => db.users.whereIn('id', ids)); await Promise.all(ids.map(i=>l.load(i)));` |

**Cartesian trap (1:N):** replacing the loop with **one eager JOIN** multiplies rows
(1 parent × N children = N duplicate rows) and **breaks `LIMIT`/pagination**. For paginated
hasMany, prefer **2 queries** (prefetch/`selectinload`/`relationLoadStrategy:'query'`),
not a JOIN. Detail in the table in `false-cures-and-gotchas.md`.

## Guardrail — query-count test assertion

Static doesn't count queries; the assertion lives in the ORM spokes. Cross-cutting: **mock the
HTTP client and assert the outbound call count is constant vs N**:

```js
// Node + nock — microservice N+1 guardrail
const scope = nock('http://svc').get(/.*/).times(Infinity).reply(200, {});
await handler({ ids: range(50) });                       // LARGE fixture
expect(scope.interceptors[0].interceptionCounter).toBeLessThanOrEqual(2);  // MAX, not exact
// or MSW: server.events.on('request:start', () => calls++)
```

**MAX, not EXACT** (warmup/auth make the exact count flaky). And **CONSTANT vs N**: run with a
small **and** a large fixture — if the count doesn't grow as N grows, it's cured;
a fixed ceiling that passes with N=1 hides the bug.

## Stack gotchas

- **Over-firing is static's Achilles heel.** `inside loop` rules fire on legit
  constant-time loops (small fixed range, in-memory collection). **Scope the inner
  `pattern` to real DB/HTTP clients** and use `pattern-not-inside` / an allowlist comment
  — **never** disable the rule globally to silence one false positive.
- **ESLint `no-await-in-loop` is incomplete alone:** it ignores `Promise.all(ids.map(async))`
  — the most common N+1 in TS (parallelized, still N calls). Pair it with the ast-grep rule.
- **ast-grep's `await $_` over-fires** on non-I/O awaits (locks, `setTimeout`). Treat it as
  triage, not verdict; confirm the awaited thing is a network/DB client.
- **`pattern-inside` with `...` in the body won't match the false-cure** of a helper called per item
  — the call left the syntactic loop. Only SQL fingerprinting (Prosopite) / span-count catches it
  (`service-fanout.md`).
- **Semgrep and ast-grep are complementary, not substitutes.** Semgrep has richer `pattern-not-inside`/
  `metavariable` for allowlisting; ast-grep is faster and has cleaner `kind`-matching for loops.
  Run both in CI; separate gates.
- **SonarQube has no single N+1 rule.** "I turned on Sonar" ≠ covered — you must curate per-language
  perf rules and pin them to the Quality Gate (`sonar.qualitygate.wait=true`), or the gate
  passes green with an N+1.

## LLM playbook (ordered, tool-first)

1. **Detect transport + loops.** `ast-grep scan` (or grep) for the loop-of-calls shape: rule
   `pattern: $C.$M($$$)` with `inside: any:[for_statement,for_in_statement,for_of_statement,while_statement] stopBy: end`. List every match — N+1 candidates (DB and HTTP).
2. **Run the custom Semgrep** `patterns:[pattern-inside:'for $X in ...: ...', pattern-either:<clients>]` via `semgrep scan --error`; exit 1 = "candidates found". Reuse the repo's config dir if it exists.
3. **JS/TS:** enable ESLint core `no-await-in-loop: error` + `eslint . --max-warnings 0`; each hit is sequential fan-out. **Don't** auto-"fix" with `Promise.all` — it hides, doesn't cure.
4. **Grep for MISSING eager-load** near the iterated queryset: Django `select_related`/`prefetch_related`; Rails `includes`/`preload`/`eager_load`; SQLAlchemy `joinedload`/`selectinload`; Prisma/TypeORM `include`/`relations`. Absence + per-item access = confirmed DB N+1.
5. **Microservice N+1:** grep the loop body for `requests.|httpx.|fetch(|axios.|RestTemplate|WebClient|Feign`. Found one? Check for a batch endpoint (`:batchGet`, `?ids=`, `whereIn`) or DataLoader; if none, it's network fan-out.
6. **Apply an allowlist instead of a global disable:** for each false positive, add `pattern-not-inside` (Semgrep) or a reviewable allowlist comment in the diff — keep the rule armed.
7. **Pin the gates in CI:** `semgrep scan --error` (exit 1), `eslint . --max-warnings 0`, `ast-grep scan` (nonzero on `severity: error`), `sonar.qualitygate.wait=true`. Each fails the pipeline on its own.
8. **Confirm at runtime** (cheap): for DB, go to the ORM spoke and use the query-count test with a large fixture; for HTTP, mock the client (nock/MSW/responses/WireMock) and assert call-count constant vs N.
9. **Cure by batching, not parallelization:** 1 `IN (...)`/batch endpoint + group-by, correct eager-load by cardinality (JOIN for 1:1·FK, 2 queries for 1:N/M:N), or per-request DataLoader. Reject `Promise.all` as a cure.
10. **Re-run 1–8 to prove the cure:** clean rules, call/query count constant vs N, trace with 1 batched span. Keep the static gates + the count assertion **permanent** in CI.

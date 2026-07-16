# Service Fan-out — HTTP / gRPC / microservice N+1 — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

The N+1 here is over the **network**: a BFF/aggregator in a loop calling `GET /thing/{id}` or
`GetUser(id)` per item. The cure is **batch** (`:batchGet`, `?ids=`, `whereIn`),
**request-coalescing**, or a **per-request DataLoader over the HTTP client** — never
`Promise.all` (it parallelizes N calls, it does not batch).

## Detect — runtime

No DB `raiseload` here — the **fail-at-point** equivalent is a request-scoped counter
that **throws** when the ceiling is exceeded, dropping the stack trace at the exact
`file:line` of the extra call. In Node use `AsyncLocalStorage` (zero deps):

```ts
// counter.ts — per-request call counter; bump() in the HTTP client wrapper, guard() before responding
import { AsyncLocalStorage } from 'node:async_hooks';
const als = new AsyncLocalStorage<{ n: number }>();
export const countCalls = (req, res, next) => als.run({ n: 0 }, next);
export const bump = () => { const s = als.getStore(); if (s) s.n++; };
export const guard = (max = 20) => {                         // call before responding
  const s = als.getStore();
  if (s && s.n > max) throw new Error(`N+1 fan-out: ${s.n} calls > ${max}`);
};
// app.use(countCalls); http.get = (u) => (bump(), realGet(u)); res.on('finish', () => guard());
```

The portable cross-language detector is the **OpenTelemetry SpanProcessor**: it counts child
HTTP/DB spans per parent and flags the trace when it passes the ceiling (works on
auto-instrumented spans from any SDK — Py/JS/Java/Go):

```py
class NPlusOneDetector(SpanProcessor):          # provider.add_span_processor(NPlusOneDetector())
  def on_end(self, span):
    a = span.attributes
    if not (a.get('db.system.name') or a.get('http.request.method')): return
    if span.parent is None: return
    pid = span.parent.span_id
    self.counts[pid] = n = self.counts.get(pid, 0) + 1
    if n == 20: span.add_event('N+1 fan-out detected', {'fanout.count': n})
```

In production, without instrumenting anything new: **offline trace analysis** (group
child spans by parent and by normalized template) or **Tempo TraceQL** on a dashboard:

```traceql
# parents (1 request) with >20 child DB/HTTP spans — the fan-out signature
{ name = "GET /api/orders" } >> { .db.system.name != "" } | count() > 20
# alt: SpanMetrics connector emits calls_total{span_name}; alert on calls/trace
```

## Detect — static / lint

The canonical shape is an **HTTP client call inside a loop**. Polyglot via ast-grep
(`inside` + `any` over the loop `kind`s, `stopBy: end`); swap the `pattern` per
ecosystem (`requests.$M`, `axios.$M`, `RestTemplate`, `Feign`):

```yaml
# call-in-loop.yml — ast-grep scan (exits != 0 on error, fails CI)
id: http-call-in-loop
language: TypeScript
severity: error
message: HTTP/RPC call inside a loop — N+1 fan-out; use a batch endpoint or DataLoader.
rule:
  pattern: $CLIENT.$M($$$)
  inside:
    any: [{kind: for_statement},{kind: for_of_statement},{kind: while_statement}]
    stopBy: end
```

```yaml
# semgrep scan --error  (catches sequential fan-out in Python)
rules:
- id: http-call-in-loop
  languages: [python]
  severity: WARNING
  message: HTTP call in a loop — N+1 fan-out; use a batch endpoint.
  patterns:
    - pattern-inside: "for $X in ...:\n  ..."
    - pattern-either: [{pattern: "requests.$M(...)"}, {pattern: "httpx.$M(...)"}]
```

JS/TS: enable the **core** rule `no-await-in-loop` (zero plugins) and run
`eslint . --max-warnings 0`. **Warning:** it only catches the *sequential* case — do not
"fix" it by wrapping in `Promise.all`, that hides the N calls (see gotchas).

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1·FK | **Request-coalescing / memo** by id: dedup repeated keys within the same request | `const get = (id) => cache.has(id) ? cache.get(id) : cache.set(id, fetchUser(id)).get(id)` |
| 1:N | Hoist the call into **ONE batch** (`:batchGet`/`?ids=`) and group-by in memory | `const items = await api.post('/items:batchGet', { ids }); const by = groupBy(items,'orderId')` |
| M:N | **Per-request DataLoader** over the HTTP client (1 instance/request, batch fn `keys[]→values[]` in order) | `const l = new DataLoader(ids => api.get('/u?ids='+ids)); await Promise.all(ids.map(id=>l.load(id)))` |

**Cartesian trap (1:N):** when fetching the batch and joining in memory, group by
`parentId` before assigning — do not run `items.filter(i=>i.orderId===o.id)` inside
the parent loop (that is O(N×M) and re-iterates the whole collection per parent). Use a single
`groupBy`/`Map` and map each parent to `map.get(o.id) ?? []`.

## Guardrail — query-count test assertion

Mock/intercept the HTTP client (nock/MSW/responses/WireMock), count **outbound**
calls, and assert the count **does not scale** with N:

```ts
// Node + nock — counts external calls; ceiling, not exact
const scope = nock('http://svc').get(/.*/).times(Infinity).reply(200, {});
test('aggregator is not fan-out N+1', async () => {
  await handler({ ids: range(50) });               // LARGE fixture
  expect(scope.interceptors[0].interceptionCounter).toBeLessThanOrEqual(2);
});
// MSW: let calls=0; server.events.on('request:start', () => calls++);
```

**Use MAX, not EXACT** (retry/health-check/token-refresh make an exact ceiling flap).
And run with **small AND large** fixtures: if the count stays **constant** as N grows,
it is cured; with 1 id both fan-out and cure yield ~1 call and the test passes falsely.

## Stack gotchas

- **`Promise.all`/`asyncio.gather` do not cure** — they fire N concurrent requests,
  now in a burst that can exhaust the connection pool and stampede the target service.
  Cure with a **batch endpoint** or **DataLoader**, not with parallelism.
- **Non-deterministic batch endpoint:** many `:batchGet` calls return **out of order**
  or **omit missing ids**. Always remap by id (`ids.map(id => rows.find(r=>r.id===id))`),
  never assume positional index.
- **DataLoader is per-request** — a module singleton leaks cache across users (a
  security bug); 1 loader per resolver defeats the batch. Create it in the request context.
  In Java, `java-dataloader` needs an explicit `dispatch()`/`dispatchAndJoin()` or
  the batch **never happens** silently.
- **Head-sampling hides the fan-out:** the trace with the most fan-out is exactly the one the
  sampler drops. Use **tail-based sampling** keyed on child-span-count, or a
  calls/trace span-metric, to retain the N+1 traces.
- **False "clean" with a 1-id fixture:** the aggregator looks OK because N=1. The outbound
  counter only proves absence of N+1 with a large seed.
- **gRPC unary in a loop is the same as HTTP in a loop:** `GetUser(id)` per item is fan-out.
  Prefer the `BatchGetUsers(ids)` RPC (server-streaming or repeated field) — same cure.

## LLM playbook (ordered, tool-first)

1. **Identify the transport:** `grep -rE "requests\.|httpx\.|fetch\(|axios\.|got\(|RestTemplate|WebClient|Feign|grpc|net/http|Faraday" src/` — list each client on an aggregator/BFF path.
2. **Run `ast-grep scan`** with `pattern: $CLIENT.$M($$$)` and `inside: any:[for_statement,for_of_statement,while_statement] stopBy: end`; each match is a fan-out candidate. Swap the `pattern` for the real client to cut noise.
3. **`semgrep scan --error`** with `patterns:[pattern-inside: 'for $X in ...: ...', pattern-either: <http clients>]`; exit 1 = candidates found. Reuse the repo's config dir if there is one.
4. **JS/TS:** enable `no-await-in-loop: error` and run `eslint . --max-warnings 0` — each hit is sequential fan-out. Do NOT auto-fix with `Promise.all`.
5. **For each candidate, check whether a batch exists:** grep for `:batchGet|/batch|\?ids=|whereIn|BatchGet` near the client. No batch + per-item call = confirmed fan-out.
6. **Confirm at runtime:** register the `AsyncLocalStorage` call counter (or OTel SpanProcessor) and hit the endpoint with a seed of **>1 id**; read how many outbound calls went out.
7. **If tracing exists**, confirm in production: Tempo TraceQL `{name="..."} >> {.http.request.method!=""} | count() > 20`, or a SpanProcessor counting child spans per parent emitting `n_plus_1.detected`.
8. **Install the CI-failing guardrail:** mock the client (nock/MSW/WireMock/responses), zero the counter, exercise the handler, assert `calls <= ceiling` with a large fixture (MAX, not exact).
9. **Cure by cardinality:** 1:1 → memo/coalescing by id; 1:N → batch endpoint + in-memory `groupBy`; M:N/fan-out → per-request DataLoader over the client. gRPC → `BatchGet` RPC.
10. **Re-measure:** run the outbound test and the trace again; confirm the count is **constant vs N** (not just "faster"). Reject a cure that is only `Promise.all`. Keep ast-grep/semgrep + outbound-count in CI.

# Node / TypeScript (Prisma, TypeORM, Sequelize, Drizzle, Knex) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

## Detect — runtime

Node has no `raiseload` that explodes at the exact `file:line` of the lazy access.
The closest thing to **fail-at-point** is a **per-request budget that throws** when
the ceiling is exceeded — it puts the stack trace right in the handler that fired
the extra query.

```ts
// npm i @olegkoval/queryd  (query-observability lib, 2026 — verify the API in its README)
import { withQueryd } from '@olegkoval/queryd/prisma';
const prisma = withQueryd(new PrismaClient(), {
  perRequestBudget: 20,
  onBudgetExceeded: (ctx) => { throw new Error(`query budget exceeded: ${ctx.count}`); },
});
```

No add-on: turn on the **native query log** and count per request with
`AsyncLocalStorage`. It's the portable detector (and it becomes the test guardrail,
section below).

```ts
// counter.ts — per-request query counter (Prisma + AsyncLocalStorage)
import { AsyncLocalStorage } from 'node:async_hooks';
export const als = new AsyncLocalStorage<{ n: number }>();
export const prisma = new PrismaClient({ log: [{ level: 'query', emit: 'event' }] });
prisma.$on('query', () => { const s = als.getStore(); if (s) s.n++; });
export const queryBudget = (max = 20) => (req, res, next) =>
  als.run({ n: 0 }, () => {
    res.on('finish', () => { const n = als.getStore()!.n;
      if (n > max) console.warn(`[N+1?] ${req.method} ${req.path} ran ${n} queries`); });
    next();
  });
```

Per-ORM log hooks (all count SELECTs per request; flag when the **same normalized
SQL** repeats N times):

| ORM | Turn on the log | Counts |
|---|---|---|
| Prisma | `new PrismaClient({ log:[{level:'query',emit:'event'}] })` + `$on('query')` | `$on` increments a counter |
| Prisma (alt) | `.$extends({ query:{ async $allOperations({model,operation,query,args}){…} } })` | intercepts every operation + call site |
| TypeORM | `logger:'all'` (or custom `logQuery`) / env `DEBUG=typeorm:*` | calls to `logQuery` |
| Sequelize | `new Sequelize(url,{ benchmark:true, logging:(sql,ms)=>… })` | callback per SQL (+duration) |
| Knex/Objection | `knex.on('query', d => …)` (Objection runs on Knex) | event per statement |

Prisma's native dev-time profiler: `@prisma/extension-optimize` (+ `@prisma/instrumentation`)
gives an AI verdict on excessive/repeated queries. In prod, count **DB spans per
trace** via `@prisma/instrumentation`/OpenTelemetry — the universal fallback.

## Detect — static / lint

```js
// eslint.config.js — CORE rule, no plugin. Catches sequential N+1 (serialized await in a loop).
export default [{ rules: { 'no-await-in-loop': 'error' } }];
```

`no-await-in-loop` **does not catch** `await` inside `.map(async)`/`Promise.all` — which
is the most common N+1 in TS (it parallelizes, but it's still N queries). Cover the gap
with ast-grep:

```yaml
# n-plus-one.yml — ast-grep scan in CI (structural, language-aware)
rule:
  pattern: 'for ($_ of $_) { $$$; await $OBJ.$METHOD($$$); $$$ }'
constraints:
  METHOD: { regex: 'findUnique|findFirst|findMany|find|findOne|query|relatedQuery|load' }
```

```yaml
# semgrep --config ./n-plus-one.yml --error  (catches the .map case the lint ignores)
rules:
- id: n-plus-one-in-loop
  patterns:
    - pattern-either:
        - pattern: $ARR.map(async (...) => { ... await $X.findMany(...); ... })
        - pattern: for (... of ...) { ... await $X.find...(...); ... }
  message: Per-item DB query (N+1). Batch with IN / include / DataLoader.
  severity: WARNING
  languages: [typescript]
```

Plugins (optional): `eslint-plugin-require-prisma-select` (forces explicit
`select`/`include`); `eslint-plugin-sequelize` (model usage, doesn't detect N+1 by itself).

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1·FK | Prisma auto-batches `findUnique()` in the same tick (built-in DataLoader) | `prisma.user.findUnique({ where:{ id } })` // resolvers batch into an `IN` |
| 1:N | Prisma `include` in one round-trip; force a JOIN with `relationLoadStrategy` | `prisma.user.findMany({ relationLoadStrategy:'join', include:{ posts:true } })` |
| 1:N | Drizzle relational query — ONE SQL regardless of depth | `db.query.users.findMany({ with:{ posts:{ with:{ comments:true } } } })` |
| 1:N | TypeORM QueryBuilder explicit join+select (or the `relations` option) | `repo.createQueryBuilder('u').leftJoinAndSelect('u.posts','p').getMany()` |
| 1:N | Sequelize `include`; `separate:true` for hasMany with order/limit | `User.findAll({ include:[{ model:Post, separate:true, order:[['createdAt','DESC']] }] })` |
| M:N | Objection `withGraphFetched` — 1 query per level (not per row) | `Person.query().withGraphFetched('[pets, movies]')` |
| M:N | Objection `withGraphJoined` — single JOIN, only to filter/order by nested | `Person.query().withGraphJoined('pets').where('pets.name','Fluffy')` |

**Cartesian trap (1:N):** `relationLoadStrategy:'join'` and `withGraphJoined` become a
single JOIN, but **multiply rows** (1 parent × N children = N duplicated rows) and
**break `LIMIT`/pagination**. For paginated hasMany, prefer the 2-query strategy:
`relationLoadStrategy:'query'` (Prisma) or `separate:true` (Sequelize).

## Guardrail — query-count test assertion

```ts
// Prisma (Jest/Vitest) — equivalent to Django's assertNumQueries
let count = 0;
prisma.$on('query', () => { count++; });
test('list endpoint is not N+1', async () => {
  count = 0;
  await getUsersWithPosts();             // seed with >1 user and >1 post each
  expect(count).toBeLessThanOrEqual(3);  // MAX, not exact; a ceiling, not 1 + N
});
```

Knex/Objection (covers Objection, which runs on Knex):

```ts
const sql: string[] = [];
const h = (d: any) => sql.push(d.sql);
beforeEach(() => { sql.length = 0; knex.on('query', h); });
afterEach(() => knex.off('query', h));
test('withGraphFetched stays bounded', async () => {
  await Person.query().withGraphFetched('pets');
  expect(sql.length).toBeLessThanOrEqual(2);
});
```

TypeORM: spy on `logQuery` (`queries.push(q)` in a custom logger). Sequelize: point
`sequelize.options.logging` at a `jest.fn()` and assert `toHaveBeenCalledTimes`.

**Use MAX, not EXACT** (auth/savepoints/warmup make an exact ceiling flake). And run
with **small AND large fixtures**: if the count **doesn't change** as N grows, it's
cured; with 1 row the N+1 and the cure both yield ~1 query and the test passes falsely.

## Stack gotchas

- **`Promise.all` doesn't cure** — it parallelizes N queries, doesn't batch. Faster on
  the clock, same load on the DB (and risk of exhausting the pool). Cure with `include`/IN/DataLoader.
- **Prisma `findUnique` auto-batches only in the same tick** and with identical
  `where`/`include`; it breaks with `OR`/`AND`, and **stops batching inside
  `$transaction`** — GraphQL resolvers silently regress to N+1.
- **`relationLoadStrategy:'join'` only on PostgreSQL/CockroachDB/MySQL.** `'query'`
  (separate queries, merged in app) is the universal fallback and is **not** a single
  round-trip. `count()` does not accept `relationLoadStrategy`.
- **`withGraphJoined` can be slower than `withGraphFetched`** on M:N/hasMany: a payload
  with huge duplication. "1 query" can be worse — look at **row volume**, not just count.
- **Sequelize hasMany with `limit`/`order` without `separate:true`** produces wrong
  results/subqueries; `separate:true` creates **1 intentional extra query** — don't
  confuse it with N+1.
- **Drizzle only guarantees 1 SQL for nested `with`.** A loop calling
  `db.query.*.findMany()` per parent reintroduces N+1 — the guarantee doesn't hold for a manual loop.
- **DataLoader is per-request.** A module singleton = cache leak across users (security
  bug); a per-resolver instance = batching nullified.
- **Lazy relations are invisible in review:** TypeORM lazy `await entity.relation`,
  Sequelize `await instance.getPosts()`/no `include`, Prisma fluent `.posts()` — they
  look like property access, each is a query.

## LLM playbook (ordered, tool-first)

1. **Identify the ORM:** `grep -E "@prisma/client|typeorm|sequelize|drizzle-orm|knex|objection" package.json` — branch the rest by what you find.
2. **Enable `no-await-in-loop` as an error** and run `npx eslint .` — each hit on a request/service path is a sequential-N+1 candidate.
3. **Run ast-grep/semgrep** for `await $X.{findUnique,findFirst,findMany,find,findOne,query,relatedQuery,load}()` inside `for-of` **and** `.map(async)`/`.forEach(async)` — the `.map` case is what the lint misses.
4. **Grep lazy/fluent relations that hide a query:** Prisma `\.\w+\(\)` in resolvers (e.g. `.posts()`), TypeORM `await entity\.\w+` lazy, Sequelize `await \w+\.get\w+\(`/no `include`, Drizzle `db.query.*.findMany` inside a loop.
5. **Grep GraphQL resolvers without DataLoader:** check that `new DataLoader(` is created **per request** in the context; flag any resolver that calls the repo per parent item.
6. **Confirm at runtime:** Prisma `$on('query')`; TypeORM `logger:'all'`/`DEBUG=typeorm:*`; Sequelize `logging+benchmark`; Knex `knex.on('query')`. Hit the endpoint with a seed of **>1 parent and >1 child** and read the SQL.
7. **Count and normalize:** if the same SQL shape repeats 1× per parent row, it's confirmed N+1. Automate with `@prisma/extension-optimize` or `@olegkoval/queryd` (`perRequestBudget`).
8. **Install the CI-failing guardrail:** subscribe to the query event, reset the counter, exercise the unit, assert `count <= budget` (Prisma `$on` / Knex `on('query')` / TypeORM `logQuery` spy / Sequelize `logging` jest.fn).
9. **Apply the cure by cardinality** (table above): Prisma `include`(+`relationLoadStrategy:'join'`), Drizzle `with`, TypeORM `leftJoinAndSelect`, Sequelize `include`(`separate:true`), Objection `withGraphFetched`, or DataLoader for cross-service/GraphQL fan-out.
10. **Re-measure:** run the test and the log again; confirm the count dropped to a **small constant** (not just got faster). Reject a `Promise.all`-only cure. Keep lint + semgrep + budget in CI.

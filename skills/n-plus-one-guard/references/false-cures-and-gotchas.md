# False Cures & Universal Gotchas

Traps that show up in **every** stack when detecting/fixing N+1. Each language
spoke assumes you read this — it's not repeated there.

## False cures (reject these)

| "Cure" | Why it does NOT cure | What to do |
|---|---|---|
| **Parallelize** (`Promise.all`, `asyncio.gather`, `gather`) | Still does **N** round-trips, just concurrent. Can make it worse: pool exhaustion/connection stampede on the DB. Only hides latency. | Real **batch**: 1 endpoint/query `IN (...)` or DataLoader. |
| **Eager JOIN on a 1:N relation** (`joinedload`/`withGraphJoined`/EF single-query) | Multiplies rows (cartesian product): 1 parent × N children = N rows; **breaks `LIMIT`/pagination**. | Prefetch in 2 queries (`prefetch_related`/`selectinload`/`AsSplitQuery`). |
| **Re-filter/map the already-prefetched relation in memory** | `.filter()`/`.where()`/`.map(async)` on the relation **re-runs the query**, nullifying the prefetch. | Filter in the DB (with `Prefetch(queryset=...)`) or in pure memory, no I/O. |
| **`.only()`/`.defer()`/projection then accessing a field outside it** | Accessing a deferred field fires a **new** query per row → fresh N+1. | Include the accessed fields in the projection. |
| **Move the N selects "out of the loop"** (e.g. `list(qs)` eager in a helper) | The N selects still happen, just elsewhere. Loop-scoped AST misses it. | A detector by **SQL fingerprint** (Prosopite) or span count catches it. |
| **Raise the test's ceiling to make it pass** | Defeats the guardrail; the N+1 ships to production. | Require a justification in the allowlist (reviewable diff). |

## Detection gotchas

- **Legit batching counts >1 query.** `selectinload`/`prefetch_related` = 2 queries;
  `withGraphFetched` = 1 per level; DataLoader = 1 `IN`. A naive counter reads the
  correct cure as "still bad". **Count query SHAPES that scale with N**, not the
  raw number.
- **The invariance is the test, not a magic number.** Run with N=1 and N=large and
  assert a **constant** count. A fixed ceiling that passes at N=1 hides the bug.
- **Prefer MAX over EXACT.** Exact-count asserts are brittle (auth, savepoints,
  schema/cache warmup, the intentional extra query from `selectinload`) and flake.
  Use exact only on a locked-down hot path.
- **The N+1 lives in serialization, not the loop.** DRF `SerializerMethodField`,
  Pydantic `from_orm`/`model_validate`, marshmallow, Rails views, GraphQL resolvers —
  all traverse relations **outside** the query builder. The cure (eager load) goes
  in the **query layer** (`get_queryset`/repository), **never** in the
  serializer/resolver.
- **Instrumentation off = false "clean".** Django `connection.queries` is empty with
  `DEBUG=False`; counters must attach BEFORE the connection opens. A zero count may
  mean instrumentation is off, not absence of N+1.
- **CACHE/SCHEMA queries inflate the counter.** Exclude them (Rails: skip
  `/SCHEMA|CACHE/`; Django: query cache) or you chase phantom N+1.
- **GraphQL is multiplicative.** Fan-out compounds across nesting levels; fixing one
  resolver can hide a deeper N+1. Test the count at the **depth that actually fans
  out**, not just the top.
- **DataLoader has 3 invariants** (any language): instantiate **per request** (module
  singleton = cache leak across users = security bug), batch within a tick, and **one
  instance per resolver kills batching**. In Java, `java-dataloader` needs an explicit
  `dispatch()` or the batch never happens.

## Bias toward native guards

Several dedicated N+1 tools are **unmaintained** (`nplusone`, `sqltap`,
`sqlalchemy-easy-profile`), while the **ORM's native guards** are first-class and
durable. Prefer these where they exist:

- SQLAlchemy `raiseload("*")` / `lazy="raise"`
- Rails `strict_loading` / `config.active_record.strict_loading_by_default`
- Laravel `Model::preventLazyLoading()`
- EF Core split query / projection to DTO (no lazy proxies)
- Hibernate `@EntityGraph` + `SQLStatementCountValidator`

...plus a homegrown **per-request query counter** (15 lines) instead of a brittle
add-on. The universal fallback that works in **any** language is counting
OpenTelemetry DB/HTTP spans per trace (see `service-fanout.md`).

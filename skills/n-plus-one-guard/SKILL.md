---
name: n-plus-one-guard
description: |
  Detects and prevents query N+1 (SQL/ORM) and redundant HTTP/service calls
  within the same request, in any language. Use when reviewing
  endpoints/handlers/resolvers, writing ORM code, suspecting latency that grows
  with payload size, or wiring a per-route query budget into CI. Stacks covered:
  Django, SQLAlchemy, Prisma, TypeORM, Sequelize, Drizzle, ActiveRecord/Rails,
  Hibernate/JPA/Spring, GORM/ent (Go), Eloquent/Doctrine (PHP), EF Core (.NET),
  Dart/Flutter (Drift/Isar/ObjectBox), GraphQL/DataLoader. Triggers: "N+1",
  "query count", "eager loading", "select_related", "prefetch", "includes",
  "JOIN FETCH", "Preload", "populate", "DataLoader", "lazy loading", "loop of
  queries", "linear latency".
source: authored
upstream: https://github.com/FelipeOFF/n-plus-one-guard-skill
license: MIT
added: 2026-06-05
---

# N+1 Query Guard

Guardrail against **N+1** and against multiple redundant queries/calls in the
same HTTP request — **language-agnostic**, with sharp playbooks for the most
common stacks. The goal isn't just "find today's N+1": it's to **detect with a
tool** (not by eye) and install a **per-endpoint query budget** that fails CI
when someone reintroduces the problem.

## When to activate

- Reviewing an endpoint/handler/resolver that iterates over a collection and
  accesses a relation (or does I/O) per item.
- Latency grows linearly with payload size (10 items = 11 queries, 100 = 101).
- Before merging code that touches the ORM, serializers, or GraphQL resolvers.
- When building the test suite for a new route (install the budget from the start).

## The mental model

An HTTP request should have a known, small **query budget**, ideally **O(1)** in
input size. N+1 is the case where the cost becomes **O(n)**: 1 query for the list
+ N queries to hydrate each item.

```
# N+1 (bad) — 1 + N
orders = Order.objects.all()              # 1 query
for o in orders:
    print(o.customer.name)                # +1 query per order

# O(1) — eager load
orders = Order.objects.select_related("customer")   # 1 query (JOIN)
for o in orders:
    print(o.customer.name)                # 0 extra queries
```

The same applies to **HTTP/service calls**: a loop that does `GET /thing/{id}`
per item is the N+1 of the network layer. The cure is the same family: **batch**
/ **bulk** / **per-request cache**. (See `references/static-analysis.md`.)

## Step 0 — Detect with a tool, not by eye

Before reasoning about the code, **let the machine point at the N+1**. There are
three classes of detector; use whatever the stack offers, preferably all three:

| Class | What it does | When it runs |
|---|---|---|
| **Runtime detector** | Instruments the ORM and shouts when the same relation is loaded repeatedly | dev / test |
| **Static / lint** | Finds "query or I/O inside a loop" and "lazy access after query" without running | pre-commit / CI |
| **Test assertion** | Asserts "this route does ≤ K queries" and fails CI on regression | CI (the guardrail) |

**Generic routine the LLM should follow** (detail in
`references/detection-playbook.md`):

1. **Identify the stack** — look for the ORM/driver: `manage.py`/`models.py`
   (Django), `schema.prisma` (Prisma), `*.rb` + `Gemfile` (Rails), `@Entity`
   (Hibernate), `gorm.io` (Go), `Model extends` (Eloquent), `DbContext` (EF Core).
2. **Turn on the stack's runtime detector** (table below) and exercise the endpoint.
3. **Run static analysis** (`references/static-analysis.md`): Semgrep/ast-grep
   for "DB/HTTP call inside loop"; the stack's native lint when it exists.
4. **Lock the budget in a test** (Step 2) — without a count assertion, there's no guardrail.
5. **Cure** with eager/batch/cache (Step 4) and re-run 1, 2, 3.

### Stack routing → reference file

| Stack | Reference | Pocket runtime detector |
|---|---|---|
| Python / Django | `references/python.md` | `nplusone`, `django_assert_max_num_queries` |
| Python / SQLAlchemy | `references/python.md` | `raiseload("*")`, `before_cursor_execute` listener |
| Node / TS (Prisma, TypeORM, Sequelize, Drizzle, Knex) | `references/node-typescript.md` | query event (`$on("query")`, logging) + test assertion |
| Ruby / Rails (ActiveRecord) | `references/ruby-rails.md` | `prosopite`, `strict_loading`, `bullet` |
| Java / Spring (Hibernate/JPA) | `references/java-spring.md` | `hypersistence-utils` SQLStatementCountValidator, QuickPerf |
| Go (GORM, ent, sqlc) | `references/go.md` | `database/sql` wrapper counting queries; GORM logger |
| PHP (Laravel Eloquent, Doctrine) | `references/php.md` | `Model::preventLazyLoading()`, `laravel-query-detector` |
| Dart / Flutter (Drift, Isar, ObjectBox) | `references/dart.md` | Drift/Isar/ObjectBox; no lazy → explicit loop; drift joins/withReferences |
| .NET (EF Core) | `references/dotnet.md` | `DbCommandInterceptor` counting; `Database.Command` logging |
| Elixir / Ecto | `references/elixir-ecto.md` | `:telemetry [repo, :query]`, `ecto_dev_logger` |
| Rust (Diesel, SeaORM) | `references/rust.md` | no lazy: N+1 is an explicit loop; `grouped_by`/`LoaderTrait` |
| MongoDB / ODMs (Mongoose, Beanie) | `references/mongo-odm.md` | `mongoose.set("debug")`, op-count; `populate` in a loop |
| GraphQL (any language) | `references/graphql-dataloader.md` | DataLoader + per-resolver counting |
| Static detection (Semgrep/ast-grep/lint) | `references/static-analysis.md` | Semgrep, ast-grep, ESLint `no-await-in-loop` |
| HTTP / gRPC / microservice N+1 | `references/service-fanout.md` | OpenTelemetry span-count; call assertion (nock/MSW/WireMock) |

> **Before curing, read `references/false-cures-and-gotchas.md`** — false cures
> (parallelize ≠ batch, cartesian JOIN on 1:N, re-filtered prefetch) and universal
> gotchas apply to every stack.
>
> No reference for the stack? Use `references/detection-playbook.md` (the method
> is the same) + the generic interceptor below.

### Generic interceptor (per-request query counter)

When there's no native helper, count queries in the scope of **one** request and
expose the total for asserts/logs. Skeleton (Python ASGI; port the concept to your stack):

```python
# Counts queries in the scope of ONE request and exposes the total for asserts/logs.
import contextvars

_query_count = contextvars.ContextVar("query_count", default=0)

def on_query_executed(*_args):          # plug into the ORM's query hook
    _query_count.set(_query_count.get() + 1)

class QueryCountMiddleware:
    """Resets at request start, logs/alerts if it exceeds the budget."""
    def __init__(self, app, soft_limit=20):
        self.app, self.soft_limit = app, soft_limit
    async def __call__(self, scope, receive, send):
        token = _query_count.set(0)
        try:
            await self.app(scope, receive, send)
        finally:
            n = _query_count.get()
            if n > self.soft_limit:
                log.warning("high_query_count", path=scope.get("path"), queries=n)
            _query_count.reset(token)
```

## Step 1 — Measure (intercept and count)

Don't trust your eye. Instrument the per-request query count and log when it
exceeds a limit. Each reference brings the stack's idiomatic hook
(`before_cursor_execute`, `prisma.$on("query")`, `ActiveSupport::Notifications`,
Hibernate `Statistics`, `DbCommandInterceptor`, GORM logger). The common
denominator is always the same: **reset a counter at request start, read it at the end.**

## Step 2 — Lock the budget in a test (the guardrail that matters)

Measurement becomes a **guardrail** when a test asserts "this route does at most
K queries". That way the regression fails CI, not production.

```python
# pytest — per-endpoint query budget assertion
def test_orders_list_query_budget(client, django_assert_max_num_queries):
    # 1 (orders) + 1 (customers via select_related) + 1 (auth) = budget 3.
    with django_assert_max_num_queries(3):
        client.get("/api/orders")
```

**Robust anti-N+1 test:** run the endpoint with 1 item and with N items and assert
the count **does not grow** with N. A fixed budget that passes with 1 item but
isn't tested with many hides the bug.

```python
@pytest.mark.parametrize("size", [1, 25])
def test_query_count_is_constant_in_size(client, query_counter, seed_orders):
    counts = []
    for size in (1, 25):
        seed_orders(size)
        query_counter.reset(); client.get("/api/orders"); counts.append(query_counter.total)
    assert counts[0] == counts[1], f"queries scale with N: {counts}"
```

> Your stack's equivalent is in the reference: `assertNumQueries` (Django),
> `SQLStatementCountValidator.assertSelectCount` (Hibernate), `n_plus_one_control`
> (Rails), assert on the `$on("query")` array (Prisma), etc.

## Step 3 — Allowlist for legitimate budgets

Not every endpoint is O(1), and that's fine. Keep a **versioned allowlist** with
the justified budget per route, so the global guardrail doesn't become noise.

```yaml
# query_budgets.yaml — per-route budget, with mandatory justification
"/api/orders":            { max_queries: 3,  reason: "list + select_related customer" }
"/api/dashboard":         { max_queries: 9,  reason: "5 independent widgets, batch impractical" }
"/api/reports/heavy":     { max_queries: 40, reason: "aggregated export; accepted, runs async" }
```

A parametrized test reads the YAML and asserts each route against its budget.
Raising a budget requires editing the file (= shows up in the diff, requires
justification in review).

## Step 4 — Cure the N+1

The cure is universal; only the method name per ORM changes (each reference has
the exact syntax).

| Symptom | Cure (concept) | Examples per stack |
|---|---|---|
| Loop accesses 1:1 / FK relation | **Eager JOIN** | `select_related` (Django), `joinedload` (SQLAlchemy), `include` (Prisma), `includes`/`eager_load` (Rails), `JOIN FETCH`/`@EntityGraph` (Hibernate), `Preload`/`Joins` (GORM), `with` (Eloquent), `.Include` (EF Core) |
| Loop accesses 1:N / M:N relation | **Prefetch in 2 queries** | `prefetch_related` (Django), `selectinload` (SQLAlchemy), `include` (Prisma), `preload` (Rails), `@BatchSize` (Hibernate), nested `with` |
| Resolver fields (GraphQL) | **DataLoader** (batch per tick) | `references/graphql-dataloader.md` |
| Loop of HTTP calls per item | **Batch / bulk / `gather`** | `references/static-analysis.md` |
| Same query repeated in the request | **Per-request memoization** | cache in request scope, never global |
| Per-item count/aggregation | **Push to the database** | `annotate`/`GROUP BY` instead of Python |

Golden rule: **resolve in the database, in batch, or in a request cache** — never
in a loop that touches I/O per item.

## Review checklist

- [ ] Ran at least one detector (runtime/static) — not just reading by eye.
- [ ] Endpoint tested with large N, not just N=1.
- [ ] There's a query-budget assertion (not just "passed").
- [ ] Loops that access relations use eager/prefetch.
- [ ] HTTP calls in loops became batch/bulk.
- [ ] A new/raised budget has justification in the allowlist.
- [ ] Heavy aggregations are in the database, not in Python/app.

## Anti-patterns

- "Works locally" with 3 records — N+1 only hurts with real data. Test with volume.
- Silently raising the budget to "make the test pass" — defeats the guardrail.
- Global cache where it should be per-request (leaks data between users).
- Eager load followed by `.filter()` on the relation in memory (redoes the query).
- Trusting human reading alone — without a detector, the N+1 returns in the next PR.

# Go (GORM, ent, sqlc) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Go has **no** magic ORM guard (no `raiseload`/`preventLazyLoading`). N+1 here is
**explicit**: a `for` firing one query per iteration. The cure is the batch
`WHERE id IN (...)` / `ANY($1)` and the guardrail is a **homegrown query counter**.

## Detect — runtime

No native fail-at-point. The closest thing to `file:line` is **blowing up on the
counter**: a request-scoped counter on the `database/sql` driver (ORM-agnostic,
works under any ORM) with `panic`/`t.Fatal` when the cap is exceeded.

```go
mw := func(ctx context.Context, _ dbwrap.Operation, _ string,
  _ []driver.NamedValue) (context.Context, func(error)) {
  if c, ok := ctx.Value(ctxKey).(*int64); ok { atomic.AddInt64(c, 1) }
  return ctx, nil
}
name, _ := dbwrap.Register("pgx", dbwrap.WithMiddleware(mw)) // bool64/dbwrap
db, _ := sql.Open(name, dsn) // ctx, n := WithCounter(r.Context()); ...; if *n>budget {…}
```

Pattern detectors / per-ORM logging (eyeball repeated identical SELECTs):

```go
// GORM: logger.Interface.Trace is called once per SQL — increment there
type counter struct{ logger.Interface; n *int32 }
func (c counter) Trace(ctx context.Context, b time.Time, fc func() (string, int64), e error) {
  atomic.AddInt32(c.n, 1); c.Interface.Trace(ctx, b, fc, e) }
// db.Session(&gorm.Session{Logger: counter{logger.Default, &n}})
```

```go
// ent: Interceptor runs on every read. dialect.Debug(drv) logs each SQL.
client.Intercept(ent.InterceptFunc(func(next ent.Querier) ent.Querier {
  return ent.QuerierFunc(func(ctx context.Context, q ent.Query) (ent.Value, error) {
    atomic.AddInt64(counterFrom(ctx), 1); return next.Query(ctx, q) }) }))
```

```go
// bun: native counter, no wrapper. delta = N+1.
delta := db.Stats().Queries - before
// or db.AddQueryHook(bundebug.NewQueryHook(bundebug.WithVerbose(true)))
```

## Detect — static / lint

```bash
# unqueryvet (MirrexOne, maintained) — flags SELECT * AND query-in-loop; knows
# 12 builders (GORM, ent, sqlc, bun, sqlx, pgx, sqlboiler, squirrel, jet…)
go install github.com/MirrexOne/unqueryvet/cmd/unqueryvet@latest && unqueryvet ./...
# .golangci.yml: linters.enable: [unqueryvet]; settings.unqueryvet.check-sql-builders: true
```

```yaml
# semgrep backstop (catches every ORM at once)
rules:
- id: go-db-query-in-loop
  languages: [go]
  message: DB query inside loop — likely N+1; eager-load before the loop
  patterns:
    - pattern-inside: "for ... { ... }"
    - pattern-either:
        - pattern: $DB.Find(...)
        - pattern: $DB.QueryContext(...)
        - pattern: $Q.Scan(...)
```

A custom `ruleguard`/`go-critic` (`m.Match` of `$db.Where(...).Find(...)` inside
`for $_, $v := range`) works as a fast PR gate when unqueryvet's list doesn't
cover your call shape.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1 · FK / belongs-to | GORM `Joins` (1 LEFT JOIN, no duplication) | `db.Joins("Company").Joins("Manager.Company").First(&user, 1)` |
| 1:N (has-many) | GORM `Preload` (separate `IN` query, stitched in Go) | `db.Preload("Orders").Preload("Orders.Items").Find(&users)` |
| M:N | GORM `Preload` (resolves the join table itself) | `db.Preload("Languages").Find(&users)` |
| 1:N (ent) | `.With<Edge>()` (1 extra query, explicit nesting) | `client.User.Query().WithPosts(func(q *ent.PostQuery){ q.WithComments() }).All(ctx)` |
| 1:N (bun) | `.Relation()` (has-many and m2m share one API) | `db.NewSelect().Model(&users).Relation("Profiles").Scan(ctx)` |
| 1:N (sqlc) | batch `WHERE id = ANY($1)` (no eager-load) | `SELECT * FROM orders WHERE user_id = ANY($1::bigint[]);` |

**Cartesian JOIN trap:** in 1:N, `Joins`/a single JOIN **multiplies rows** (1 parent ×
N children) and breaks `LIMIT`/pagination. Use `Joins` only for 1:1/FK; for has-many
go with `Preload` (2 queries) — sometimes 2 queries beat one giant JOIN. Count
**rows AND queries**.

**No mapped association?** `Joins("Customer")`/`Preload(...)` need a relation field on the
struct (`Customer Customer` + matching FK). If the model only has the raw FK
(`o.CustomerID`), don't query per row — collect the ids and **batch once**, then stitch in
Go: `db.Where("id IN ?", ids).Find(&customers)` (GORM) or `... WHERE id = ANY($1)` (sqlc).

## Guardrail — query-count test assertion

```go
// driver-wrapper delta (max fidelity: runs the real SQL)
var n int64
ctx := context.WithValue(req.Context(), ctxKey, &n)
ListOrders(ctx, db)                 // actually exercises the preload
if n > 3 { t.Fatalf("N+1: %d queries, budget 3", n) }
```

```go
// bun: cheapest, no wrapper
start := db.Stats().Queries
repo.ListUsersWithProfiles(ctx)
if got := db.Stats().Queries - start; got > 2 { t.Fatalf("N+1: got %d (>2)", got) }
```

go-sqlmock: declare **exactly** the expected queries (one `ExpectQuery` per SQL);
one extra query per row fails `ExpectationsWereMet()`.

Use **MAX, not EXACT** (auth/prepare/warmup flicker the exact count). And run with a
**small AND large** fixture: a good cap is **constant** — N=1 and N=1000 must yield
the same count. A cap that only passes at N=1 hides the bug.

## Stack gotchas

- **`Joins` ≠ `Preload`, they're not interchangeable.** `Joins` on has-many
  duplicates parent rows; a `Preload` re-emitted **inside** a `range` is still N+1 —
  the preload belongs on the LIST query, never per element.
- **`db.Stats().Queries` (bun) is process-global**, not per request. Snapshot the
  delta around the unit under test and **serialize** the test (no parallel queries)
  or you'll count queries from other goroutines.
- **ent doesn't cascade `With`:** forgot `.With<Edge>()` → lazy-load per access = N+1.
  Nesting must be declared explicitly; `WithFoo()` without a limit can over-fetch.
- **sqlc has no eager-load by design:** one `:one` per ID inside the loop IS N+1. The
  cure is a single `ANY($1)` query taking all parent IDs at once.
- **Counting on the `database/sql` driver misses queries served from an ORM cache**;
  and GORM `PrepareStmt` splits 1 logical query into prepare+exec — decide whether
  you count **statements or round-trips** before fixing the budget.
- **unqueryvet/semgrep loop-detection is lexical:** a query in a helper called from
  inside the loop is **not** flagged. Combine static lint with a runtime/test counter.

## LLM playbook (ordered, tool-first)

1. **Identify the stack:** `grep -E 'gorm.io/gorm|entgo.io/ent|sqlc|volatiletech/sqlboiler|uptrace/bun' go.mod` → picks idiom + counter.
2. **Lint first (no DB):** `go install github.com/MirrexOne/unqueryvet/cmd/unqueryvet@latest && unqueryvet ./...`.
3. **Grep query-in-loop:** `grep -rnE 'for .*\{' -A15 --include=*.go . | grep -E '\.(Find|First|Scan|Get|Load|QueryContext|All)\('`.
4. **Grep for MISSING eager-load:** GORM `grep -rn '.Find(' | grep -v 'Preload\|Joins'`; ent `grep -rn '.All(ctx)' | grep -v 'With'`; bun `grep -rn '.Scan(ctx)' | grep -v 'Relation('`. Hits = candidates.
5. **Runtime counter for the matched ORM:** GORM → `logger.Interface` summing in `Trace`; bun → `db.Stats().Queries` delta; ent → global `ent.InterceptFunc`; else wrap `database/sql` with `bool64/dbwrap`.
6. **Test the suspect route** with an N-parent fixture, assert count ≤ small budget (exact sqlmock, or wrapper delta, or bun DBStats). `go test ./... -run N+1`.
7. **Confirm it FAILS** on the current code (proves the N+1 and the guard), then cure: `Preload`/`IN` for 1:N, `Joins` for 1:1, `.With<Edge>()` ent, `Relation()` bun, `ANY($1)` sqlc.
8. **Re-run** the test (passes the budget) and wire it into CI: golangci-lint with unqueryvet + the budget test. A regression fails the pipeline.
9. **Prod:** turn on otelsql/bunotel spans and read the waterfall of a list endpoint — N sibling spans of the same SQL under one parent = live N+1.

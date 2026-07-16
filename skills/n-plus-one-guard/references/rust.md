# Rust (Diesel + SeaORM) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Rust **has no implicit lazy loading**: an unloaded association is an empty `Vec`/`Option`
field, not a hidden query. So N+1 here is **always an explicit loop** firing one query per
item. The cure is the 2-query batch (Diesel `belonging_to`+`grouped_by`; SeaORM
`LoaderTrait`) and the guardrail is **counting queries**. Targets: Diesel 2.2+, SeaORM 1.1+,
async-graphql 7.x.

## Detect — runtime

**Fail-at-point first — Diesel `Instrumentation` (native, 2.2+).** There's no lazy-access
exception (lazy doesn't exist), but `Instrumentation` gets one `InstrumentationEvent` per
query at the call's `file:line` — make it **blow up** when the budget is exceeded.

```rust
use diesel::connection::{Instrumentation, InstrumentationEvent as E};
struct Budget { n: u32, max: u32 }
impl Instrumentation for Budget {
    fn on_connection_event(&mut self, ev: E<'_>) {
        if let E::StartQuery { .. } = ev { self.n += 1;
            assert!(self.n <= self.max, "N+1: query #{} > budget {}", self.n, self.max); }
    }
}
conn.set_instrumentation(Budget { n: 0, max: 3 }); // or set_global_instrumentation(|| ...)
```

SeaORM/SQLx have no fail-at-point hook: the path is **query-logging**. Enable `sqlx_logging`
and read repeated identical SELECTs (eyeball), or count via test (below).

```rust
let mut opt = ConnectOptions::new(url);
opt.sqlx_logging(true).sqlx_logging_level(log::LevelFilter::Debug); // RUST_LOG=sqlx::query=trace
let db = Database::connect(opt).await?;          // N twin SELECTs under 1 request = N+1
```

`diesel-tracing` (maintained) emits 1 tracing span per query — count sibling spans of the same
SQL in a list endpoint to flag N+1 in prod without hand-instrumenting.

## Detect — static / lint

No native N+1 analyzer in Rust. Use **semgrep/ast-grep** to catch lexical query-in-loop:

```yaml
# semgrep — query inside for (Diesel .load / SeaORM .one/.all inside the loop)
rules:
- id: rust-db-query-in-loop
  languages: [rust]
  message: DB query inside loop — likely N+1; batch before the loop
  patterns:
    - pattern-inside: "for $X in $IT { ... }"
    - pattern-either:
        - pattern: $Q.load::<$T>($C)
        - pattern: $E::find_by_id($ID).one($C).await
        - pattern: $E::find().filter(...).all($C).await
```

`ast-grep --pattern '$Q.load::<$_>($_)'` inside a `for` block works as a fast PR gate.
`cargo clippy` has **no** N+1 lint — don't rely on it for this.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1 · FK / belongs-to | Diesel single JOIN (no parent duplication) | `users::table.inner_join(companies::table).load::<(User, Company)>(c)?` |
| 1:1 · FK (SeaORM) | `find_also_related` (LEFT JOIN, 1 query) | `User::find().find_also_related(Company).all(db).await?` |
| 1:N (has-many) | Diesel `belonging_to`+`grouped_by` (2 queries) | `let ps = Post::belonging_to(&users).load::<Post>(c)?.grouped_by(&users); users.into_iter().zip(ps)` |
| 1:N (SeaORM) | `LoaderTrait::load_many` (2 queries, no cartesian) | `let posts = users.load_many(post::Entity, db).await?;` |
| M:N | `LoaderTrait::load_many_to_many` (resolves the join table) | `let tags = posts.load_many_to_many(tag::Entity, post_tag::Entity, db).await?;` |
| 1:1 load (SeaORM) | `LoaderTrait::load_one` (has_one/belongs_to) | `let companies = users.load_one(company::Entity, db).await?;` |
| 1:N in GraphQL | async-graphql `DataLoader` (batch per tick) | `ctx.data_unchecked::<DataLoader<PostLoader>>().load_one(user.id).await?` |

**Cartesian JOIN trap (1:N):** SeaORM `find_with_related`/Diesel JOIN on has-many
**multiplies rows** (1 parent × N children) and breaks `LIMIT`/pagination — sends the parent N
times over the wire. Use JOIN only for 1:1/FK; for has-many go with `load_many`/`grouped_by`
(2 queries). Count **rows AND queries**.

async-graphql `Loader::load` takes `&[K]` and returns `HashMap<K, Value>` — one batch query
per key set; `load_one(id)` in the resolver enqueues and the loader resolves all in the same tick.

```rust
#[async_trait::async_trait]
impl Loader<i32> for PostLoader {
    type Value = Vec<Post>; type Error = Arc<DbErr>;
    async fn load(&self, ids: &[i32]) -> Result<HashMap<i32, Self::Value>, Self::Error> {
        // 1 SELECT ... WHERE user_id = ANY($1) — then group by user_id into the HashMap
        Ok(group_by_user(query_posts(ids).await?))
    }
}
```

## Guardrail — query-count test assertion

```rust
// SeaORM: MockDatabase records each Statement — count the transaction log
let db = MockDatabase::new(DbBackend::Postgres)
    .append_query_results([vec![user::Model { /* … */ }]])
    .append_query_results([vec![post::Model { /* … */ }]]).into_connection();
list_users_with_posts(&db).await?;
assert!(db.into_transaction_log().len() <= 2, "N+1: > 2 queries"); // budget, not exact
```

```rust
// Diesel: the Instrumentation Budget already asserted at runtime; in the test, count and compare
let mut b = Budget { n: 0, max: 2 };
conn.set_instrumentation(/* &mut b via Box exposing n */);
list_with_posts(conn)?;            // n must be CONSTANT with 1 or 1000 parents
```

Use **MAX, not EXACT** (warmup/migration/ping flicker the exact count). Run with a **small AND
large** fixture: a good budget is **constant** — N=1 and N=1000 must give the same count. A
budget that only passes at N=1 hides the bug.

## Stack gotchas

- **`grouped_by` does NOT emit SQL `GROUP BY`** — it's an in-memory zip over already-loaded
  `Vec`s. It depends on **parent order**: pass the **same** `&users` to `belonging_to` and
  `grouped_by`, otherwise children attach to the wrong parent (no error, corrupted data).
- **SeaORM eager-load covers at most 2 entities** at a time (`load_*` is 2 queries). Nesting
  beyond 2 levels needs the **Entity Loader** (`load_relation`) or manual `LoaderTrait`
  chains — chaining `find_with_related` across 3 tables becomes an explosive cartesian.
- **`find_with_related` (JOIN) vs `LoaderTrait` (2 queries) are not interchangeable:** the
  first duplicates the parent in 1:N; the second doesn't. Choose by cardinality, not habit.
- **async-graphql `DataLoader` only batches within the same async tick** — sequential `.await`
  in a `for` (instead of `load_one` in parallel via `join_all`/resolver) serializes and
  becomes N+1 again. One `DataLoader` per request; reusing across requests leaks cache.
- **`set_instrumentation` is per-connection**: in a pool (r2d2/bb8/deadpool) every connection
  needs the hook, or use `set_global_instrumentation` (global constructor) to cover all.
- **Async streams fool the counter:** `load_stream`/page cursor can emit 1 query per chunk —
  count **round-trips**, and set the budget knowing the batch size.

## LLM playbook (ordered, tool-first)

1. **Identify the stack:** `grep -E '^diesel|^sea-orm|^async-graphql' Cargo.toml` → picks idiom (Diesel `grouped_by` / SeaORM `LoaderTrait` / GraphQL `DataLoader`) + counter.
2. **Grep query-in-loop (no DB):** `grep -rnE 'for .+\{' -A12 --include=*.rs src | grep -E '\.load::<|\.one\(|\.all\(|find_by_id'`. Each hit = N+1 candidate.
3. **Grep MISSING eager-load:** Diesel `grep -rn '.load::<' src | grep -v 'belonging_to\|grouped_by\|inner_join'`; SeaORM `grep -rn '.all(db' src | grep -v 'load_many\|load_one\|find_with_related\|find_also_related'`. Hits = suspects.
4. **Semgrep/ast-grep** with the `rust-db-query-in-loop` rule above as a lexical backstop in CI.
5. **Instrument the suspect path:** Diesel → `conn.set_instrumentation(Budget{max})` that `assert!`s on `StartQuery`; SeaORM → `MockDatabase` + `into_transaction_log().len()` in the test, or `sqlx_logging(true)` + `RUST_LOG=sqlx::query=trace` to eyeball.
6. **Write the test with N parents** and assert count ≤ small budget. **Confirm it FAILS** on the current code (proves the N+1 and the guard).
7. **Cure by cardinality:** 1:1 → JOIN (`inner_join`/`find_also_related`); 1:N → `grouped_by`/`load_many`; M:N → `load_many_to_many`; GraphQL → `DataLoader::load_one`.
8. **Re-run** the test (passes) and wire it into CI: the budget test + semgrep. Run with small AND large fixtures — count must stay **constant**.
9. **Prod:** enable `diesel-tracing`/`sqlx::query` spans and read the waterfall of a list endpoint — N sibling spans of the same SQL under one parent = live N+1.

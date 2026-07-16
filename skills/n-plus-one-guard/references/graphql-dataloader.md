# GraphQL — DataLoader (cross-language) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

GraphQL N+1 is born in resolution: each item of a list resolves a relation field
and fires 1 query. The canonical cure is the **DataLoader**: it collects all requested keys
within **the same event-loop tick** and fires **1 batch** (`WHERE id IN (...)`).
The 3 invariants: **one instance per request**, **batch within a tick**, **one loader per
resolver kills batching**.

## Detect — runtime

GraphQL has no `raiseload` that blows up at the exact `file:line` of the lazy access. The
closest thing to **fail-at-point** lives in the ORM layer behind the resolver — turn on the
stack's detector and make it **raise** (not just log):

```python
# Django (Strawberry/Graphene/Ariadne over Django ORM): nplusone raises on lazy access
INSTALLED_APPS += ['nplusone.ext.django']
MIDDLEWARE = ['nplusone.ext.django.NPlusOneMiddleware', *MIDDLEWARE]
NPLUSONE_RAISE = True  # turns into an exception at the non-prefetched access point
```

```ruby
# Ruby (graphql-ruby / graphql-batch over ActiveRecord): Bullet raises in the test
Bullet.enable = true; Bullet.bullet_logger = true
Bullet.raise = true  # fails the test on detected N+1 (prosopite is stricter)
```

Pattern-detectors / counters per language (flag when spans/queries repeat per item):

```ts
// JS/TS — Apollo: per-field resolver count exposes the resolver that runs N times
import { ApolloServerPluginInlineTrace } from '@apollo/server/plugin/inlineTrace';
new ApolloServer({ plugins: [ApolloServerPluginInlineTrace()] }); // gate out of prod
```

```java
// Java (graphql-java): statistics on the registry. batchLoadCount ~1 per loader/request.
DataLoaderRegistry reg = DataLoaderRegistry.newRegistry().build();
Statistics s = reg.getStatistics(); // high loadCount + batchLoadCount==1 => batched OK
// s.getBatchLoadCount() == s.getLoadCount() => NO batching (N+1)
```

Universal: **OpenTelemetry** instrumenting GraphQL + DB driver. In a trace, group
`db.query` spans by normalized SQL within 1 `graphql.operation`; a group > N = N+1.
Sentry has a built-in **N+1 DB Queries detector**.

## Detect — static / lint

```yaml
# semgrep — per-item fetch inside the resolver, no loader.load()
rules:
- id: resolver-peritem-fetch
  patterns:
    - pattern-either:
      - pattern: $XS.map(async ($X) => { ... $REPO.findOne(...) ... })
      - pattern: for (const $X of $XS) { ... await $DB.query(...) ... }
  message: Per-item fetch in resolver; use DataLoader.load()
  languages: [typescript, javascript]
  severity: WARNING
```

```yaml
# ast-grep (Python/Django) — loop touches FK/relation without select_related/prefetch_related
id: missing-eager-load
rule:
  pattern: 'for $O in $QS: $$$  $O.$REL.$$$'
  not:
    inside: { pattern: '$QS = $M.objects.$$$.select_related($$$)' }
message: Relation access in loop without select_related/prefetch_related
```

Ruby: `rubocop-graphql` + heuristic grep — a resolver that returns `object.<assoc>`
directly (without `dataloader.with(`/`Loader.for(`/`.load(`) is the smell. Go: grep for
`repo.Find`/`db.Query` in a `*Resolver` method without `loader.Load(`. SDL: `@graphql-eslint/eslint-plugin`.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1·FK | JS BatchDataLoader keyed by FK; remaps in key order | `new DataLoader(ids => db.user.findMany({where:{id:{in:ids}}}).then(r => ids.map(id => r.find(x=>x.id===id) ?? null)))` |
| 1:1·FK | .NET HotChocolate source-gen `[DataLoader]` → `Dictionary` | `[DataLoader] static Task<Dictionary<int,Brand>> GetBrandByIdAsync(IReadOnlyList<int> ids, Ctx db, …) => db.Brands.Where(b=>ids.Contains(b.Id)).ToDictionaryAsync(b=>b.Id)` |
| 1:N | .NET `GroupedDataLoader`/`ILookup` — 1 parent key → many children | `[DataLoader] static Task<ILookup<int,Product>> …(IReadOnlyList<int> brandIds,…){ var it=await db.Products.Where(p=>brandIds.Contains(p.BrandId)).ToListAsync(); return it.ToLookup(p=>p.BrandId);}` |
| 1:N | Java Spring-for-GraphQL `@BatchMapping` (automatic request-scoped batch) | `@BatchMapping(typeName="Author") Map<Author,List<Book>> books(List<Author> a){ … groupingBy(Book::getAuthorId) … }` |
| 1:N | Python Django: `prefetch_related` (separate IN, NOT JOIN) | `Author.objects.prefetch_related('books').all()` |
| M:N | Ruby graphql-batch `AssociationLoader` for has_many :through | `AssociationLoader.for(Book, :authors).load(object)` |
| M:N | Go gqlgen + `dataloadgen` mapped by join id | `dataloadgen.NewLoader(repo.GetTagsByPostIDs, dataloadgen.WithWait(time.Millisecond))` → `loader.Load(ctx, post.ID)` |

**Cartesian trap (1:N):** swapping `prefetch_related` for `select_related` (or a single
`WHERE id IN` JOIN) on a has-many **multiplies rows** (1 parent × N children) and breaks
`LIMIT`/pagination. Rule: **FK/1:1 → select_related/JOIN; 1:N and M:N → prefetch_related/
GroupedDataLoader/ILookup** (two IN queries, merge in the app).

## Guardrail — query-count test assertion

```python
# pytest-django: cap = batched count; N+1 (grows with the list) blows past it
def test_no_nplusone(client, django_assert_max_num_queries):
    with django_assert_max_num_queries(3):       # MAX, not exact
        client.post('/graphql/', {'query': LIST_WITH_RELATION})
```

```ruby
# Rails 7.2+ — ActiveRecord::Assertions::QueryAssertions
assert_queries_count(2) { MySchema.execute(LIST_POSTS_WITH_AUTHOR_QUERY) }
```

```java
// graphql-java — statistics prove batching, not time
graphQL.execute(input);
Statistics s = registry.getStatistics();
assertThat(s.getBatchLoadCount(), equalTo(1L));            // 1 batch per loader
assertThat(s.getLoadCount(), greaterThan(s.getBatchLoadCount())); // many loads, 1 batch
```

```ts
// JS/TS — spy on batchLoadFn: 1 call with an array of N keys, not N calls
const batchFn = jest.fn(keys => loadUsers(keys));
const loader = new DataLoader(batchFn);
await server.executeOperation({ query: LIST });
expect(batchFn).toHaveBeenCalledTimes(1);
expect(batchFn.mock.calls[0][0].length).toBe(N);
```

Go: `go-sqlmock` `mock.ExpectQuery(\`SELECT .* WHERE id IN\`)` **once** + `ExpectationsWereMet()`.

**Use MAX, not EXACT** (auth/warmup make an exact cap flaky). And run **CONSTANT-vs-N**:
exercise with **1 item and with 10 distinct items** — if the count **doesn't grow**, it's
cured. A fixed cap (e.g. 3) passes on 3 rows and is still N+1. DataLoader **dedupes equal
keys**: use **distinct parents (N>1 unique)** or the batch vanishes and the test lies.

## Stack gotchas

- **Batching is per tick.** `await loader.load(x)` in a sequential `for` forces 1 tick per
  item → **zero batching**. Use `Promise.all(items.map(i => loader.load(i.id)))` to
  register all `.load` calls in the same tick.
- **java-dataloader needs an explicit `dispatch()`** — the `DataLoaderDispatcherInstrumentation`
  (or Spring GraphQL) calls it for you; off that path, without `dispatchAll()` the batch never fires.
- **HotChocolate v15+: a manually registered loader stays in auto-dispatch and does NOT batch.**
  Use the source-gen `[DataLoader]` attribute (or `AddDataLoader`) so the generator wires the dispatch.
- **`dataloadgen.WithWait` defaults to 16ms.** Too low (or a non-request-scoped loader)
  splits the batch into windows. Create it per request via middleware and read from `ctx`.
- **DataLoader is per request, always via a context factory.** A module singleton = cache
  leaks across users (stale + security bug); **1 loader per resolver = batching nullified**.
- **Nested N+1:** curing the top-level loader just pushes the problem 1 level down (`author→company`).
  Detect **every relation edge**, not just the first.
- **Post-mutation cache:** a loader populated in a query serves stale data after a write in the same
  request — call `loader.clear(id)`/`clearAll()` after mutations.
- **`Promise.all` is not a cure** — it parallelizes N queries, doesn't batch. Faster on the clock,
  same load on the DB. Only DataLoader/IN collapses into 1 query.

## LLM playbook (ordered, tool-first)

1. **Identify the stack by the loader package:** `grep -rEl "from 'dataloader'|java-dataloader|graphql-batch|strawberry.dataloader|aiodataloader|dataloadgen|graph-gophers/dataloader|GreenDonut|HotChocolate" .` (package.json/pom.xml/Gemfile/pyproject.toml/go.mod/*.csproj).
2. **List resolvers returning types/lists with a relation:** `grep -rn -E 'resolve[A-Z_]|@BatchMapping|def resolve_|\[DataLoader\]|func .*Resolver' src/` — that's the N+1 surface.
3. **Find the smell — per-item fetch in a loop without a loader:** `grep -rn -E '\.map\(|for .* in |for \(' <resolvers> | grep -vi 'load('`, then inspect hits with `.findOne/.query/.objects.get/repo.Find/db.` keyed by parent id.
4. **ORM eager-load audit:** Django `grep -rn 'objects\.' . | grep -v 'select_related\|prefetch_related'`; Rails `grep -rn 'object\.' app/graphql | grep -v 'includes\|preload\|\.load('` — confirm the loop touches a relation without preload.
5. **Confirm the loader EXISTS and is request-scoped:** `grep -rn 'new DataLoader\|NewLoader\|DataLoader(load_fn\|Loader.for\|AddDataLoader' .` — verify it's created in the context factory/middleware, **not** at module/global scope.
6. **Check batching-per-tick (JS):** `await loader.load` inside a sequential `for`/`for await` (anti-pattern) vs `Promise.all(items.map(i => loader.load(i.id)))` (correct). Flag serial awaits.
7. **Turn on 1 runtime detector for a local run:** Django `nplusone.ext.django` + `NPLUSONE_RAISE=True`; Rails `Bullet`/`prosopite` in the test env; JS/Java Apollo inline-trace / java-dataloader statistics.
8. **Reproduce CONSTANT-vs-N:** run the list query with **1 item, then 10 distinct ones**, counting queries (request-scoped counter / sql logger / pg_stat). If it grows with N, it's N+1.
9. **Write the guardrail that FAILS CI:** Python `django_assert_max_num_queries(3)`; Rails `assert_queries_count(2)`; Java `getBatchLoadCount()~1 < getLoadCount()`; JS `toHaveBeenCalledTimes(1)` + length; Go `go-sqlmock ExpectQuery('IN')` once.
10. **Apply the idiom by cardinality:** FK/1:1 → BatchDataLoader/select_related; 1:N → GroupedDataLoader/ILookup, `@BatchMapping`, prefetch_related; M:N → association/mapped loader keyed by join id. Re-run 8-9 to prove a constant count.
11. **Recurse 1 level:** after batching the top, repeat 2-9 on the nested relations (`author→company`) to catch the N+1 that moved.
12. **Pin it in CI:** the count assertion in the suite **and** (optionally) an APM/trace rule (Sentry N+1 detector or OTel span-count) to catch regressions in staging.

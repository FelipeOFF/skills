# Dart / Flutter — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Dart has **no implicit lazy-loaded ORM relations** like Hibernate/Eloquent: an unloaded
relation is an empty field, not a hidden query — except ObjectBox/Isar, where accessing a
`ToOne`/`ToMany`/`IsarLink` *does* hit the DB lazily on first touch. So N+1 is almost always
an **explicit per-item query/await loop**, and in Flutter a **per-list-item `FutureBuilder`/
`StreamBuilder`** firing one DB/HTTP call per visible row. Targets: drift 2.18+, isar 3.x,
objectbox 4.x, floor 1.5+, serverpod 2.x, conduit 5.x.

## Detect — runtime

**Drift — log every statement.** No fail-at-point lazy guard exists (lazy doesn't exist in
drift). Pass `logStatements: true` to the executor and count repeated identical SELECTs under
one operation.

```dart
final db = AppDb(NativeDatabase(file, logStatements: true)); // prints every SQL stmt
// N identical "SELECT * FROM categories WHERE id = ?" under one request = N+1
```

**Fail-at-point substitute — operation-scoped statement counter via `QueryInterceptor`.**
Wrap the executor; `runSelect`/`runCustom` fire once per statement — throw past a budget.

```dart
class BudgetInterceptor extends QueryInterceptor {
  int n = 0; final int max;
  BudgetInterceptor(this.max);
  @override
  Future<List<Map<String, Object?>>> runSelect(e, String sql, List<Object?> a) {
    if (++n > max) throw StateError('N+1: query #$n > budget $max');
    return super.runSelect(e, sql, a);
  }
}
final db = AppDb(NativeDatabase(file).interceptWith(BudgetInterceptor(3)));
```

`driftRuntimeOptions.debugPrint` redirects where those logs go (route to a counter in tests).
For **HTTP-per-item** use the same service-fanout counter — see `references/service-fanout.md`.

## Detect — static / lint

No native N+1 analyzer for Dart. Use **semgrep/ast-grep** to catch a query/await inside a loop:

```yaml
rules:
- id: dart-db-query-in-loop
  languages: [dart]
  message: DB query / link access inside loop — likely N+1; batch before the loop
  patterns:
    - pattern-inside: "for (...) { ... }"
    - pattern-either:
        - pattern: await $Q.getSingle()
        - pattern: await $LINK.load()
        - pattern: $BOX.get($ID)
```

`ListView.builder` with a `FutureBuilder`/`StreamBuilder` in `itemBuilder` is the Flutter
red flag — `grep -rn 'itemBuilder' lib | xargs grep -l 'FutureBuilder\|StreamBuilder'`.

## Fix — eager idioms by cardinality

| Lib · Relation | Idiom | Snippet |
|---|---|---|
| Drift 1:1 (FK) | `leftOuterJoin` + `readTableOrNull` (1 query) | `select(items).join([leftOuterJoin(cats, cats.id.equalsExp(items.cat))])` |
| Drift 1:N | manager `withReferences` prefetch (no per-row `getSingle`) | `managers.cats.withReferences((p) => p(items: true)).get()` |
| Drift batch by id | `column.isIn([...])` (one `WHERE id IN`) | `(select(cats)..where((c) => c.id.isIn(ids))).get()` |
| Isar links | `query.findAll()` then batch `link.load()` | `final ps = await isar.posts.where().findAll(); for (p in ps) await p.author.load();` |
| ObjectBox | `query.eager(...)` (1 level, prefetch) | `box.query().eager(Order_.lines).build().find()` |
| ObjectBox by id | `box.getMany(ids)` (one multi-get) | `final users = box.getMany(authorIds);` |
| Floor / sqflite | `@Query('... IN (:ids)')` or a JOIN | `@Query('SELECT * FROM Post WHERE authorId IN (:ids)')` |
| Serverpod | `include:` in one query | `Order.db.find(s, include: Order.include(lines: Line.includeList()))` |
| Conduit | `Query..join` | `q.join(set: (o) => o.lines); await q.fetch();` |

Drift `withReferences`: prefetched rows live in `refs.<rel>.prefetchedData` — read that, **not**
`await refs.<rel>.getSingle()` (the latter re-queries per row = the N+1 you're removing).

```dart
final rows = await managers.todoItems
    .withReferences((p) => p(category: true)).get();
for (final (todo, refs) in rows) {
  final category = refs.category?.prefetchedData?.firstOrNull; // no per-row query
}
```

**Cartesian JOIN trap (1:N):** an `innerJoin`/`leftOuterJoin` on a has-many multiplies parent
rows and breaks `limit()`/pagination. Use JOIN only for 1:1/FK; for has-many use `withReferences`
(drift) / `includeList` (serverpod) / batched `isIn` / `getMany`. Count **rows AND queries**.

**Many-to-one FK (many rows → one parent, e.g. `todo.categoryId` → category):** the cleanest
drift cure is to collect the parent ids and run **one** batched read before building the list —
`(select(categories)..where((c) => c.id.isIn(todos.map((t) => t.categoryId).toList()))).get()` —
then map in memory. `withReferences` also works; don't `getSingle()` per row, and don't JOIN
just to read one parent column.

## Guardrail — query-count test assertion

```dart
test('list endpoint is N+1 free', () async {
  final counter = BudgetInterceptor(2);                 // budget, not exact
  final db = AppDb(NativeDatabase.memory().interceptWith(counter));
  await seedManyParents(db, 1000);                      // large fixture
  await listItemsWithCategory(db);                      // exercise the path
  expect(counter.n, lessThanOrEqualTo(2), reason: 'N+1: > 2 queries');
});
```

Use **MAX, not EXACT** (migrations/pragmas flicker the count). Run with a **small AND large**
fixture: a correct budget is **constant** — N=1 and N=1000 parents must give the same count.
A budget that only passes at N=1 hides the bug. For HTTP fan-out, count client calls with a
mock `http.Client` the same way.

## Stack gotchas

- **ObjectBox/Isar relations ARE lazy** (unlike drift): first touch of `ToOne`/`ToMany`/
  `IsarLink` hits the DB and caches. A `for` loop reading `entity.author.target` /
  `await link.load()` per object is a real N+1 — `eager()` (ObjectBox) only resolves **one
  level deep**; deeper nesting still fans out.
- **Isar `.load()` is per-link** — loading links for a list is still 1 op per object. There is
  no single-query join; prefer **embedded objects** over links when you always read them, or
  accept the batched-load loop and budget for it.
- **Drift `withReferences` re-queries if you call `.getSingle()`** on the ref instead of reading
  `prefetchedData` — the prefetch is wasted and you're back to N+1. Read the field.
- **Drift streams in a `ListView.builder`**: one `watch()`/`StreamBuilder` per item opens N live
  queries that all re-fire on any write. Hoist a single `watch()` above the list and pass slices
  down. Same for `FutureBuilder` doing a `getSingle()` per row.
- **Floor list binding**: `IN (:ids)` only works when the param is a `List`; a per-id DAO call in
  a loop is the N+1 — there's no eager-relation API in Floor, you hand-write the JOIN / `IN`.
- **Serverpod**: only `include:`/`includeList:` fetch in one query; reading a relation field
  *after* a plain `find` (without include) triggers a separate query per row. Conduit needs an
  explicit `Query..join`; lazy access of an unfetched relation throws, not silently re-queries.
- **isar 3.x is in maintenance / community-forked (isar_community)**; **moor** is the old name
  for **drift** — verify the package name in `pubspec.yaml` before quoting APIs.

## LLM playbook (ordered, tool-first)

1. **Identify the stack:** `grep -E '^\s*(drift|isar|objectbox|floor|serverpod|conduit):' pubspec.yaml` → picks idiom + counter (drift `withReferences` / objectbox `getMany`+`eager` / isar `load` / floor `IN` / serverpod `include`).
2. **Grep query/link-in-loop (no run):** `grep -rnE 'for \(|\.map\(' -A8 lib | grep -E 'getSingle\(|\.load\(\)|\.get\(|\.target|findById'`. Each hit = N+1 candidate.
3. **Grep Flutter UI fan-out:** `grep -rln 'itemBuilder' lib | xargs grep -l 'FutureBuilder\|StreamBuilder\|watch(\|getSingle('` → per-item DB/HTTP call to hoist.
4. **Semgrep/ast-grep** with the `dart-db-query-in-loop` rule above as a CI lexical backstop.
5. **Instrument the suspect path (drift):** `NativeDatabase(.., logStatements: true)` to eyeball repeated SELECTs, or wrap `interceptWith(BudgetInterceptor(max))` that throws on `runSelect`. HTTP → mock `http.Client` and count.
6. **Write the test with N=1000 parents** and assert count ≤ small budget. **Confirm it FAILS** on current code (proves both the N+1 and the guard).
7. **Cure by cardinality:** 1:1 → `leftOuterJoin`+`readTableOrNull`; 1:N → drift `withReferences` / serverpod `includeList` / batched `isIn` / objectbox `getMany`; ObjectBox/Isar → `eager()` / batched `load()`; Flutter → hoist one fetch above the `ListView`.
8. **Re-run** the test (passes) and wire it into CI: the budget test + semgrep. Run small AND large fixtures — count must stay **constant**.
9. **Prod:** keep `logStatements`/a `QueryInterceptor` behind a debug flag and scan a list endpoint's log for N sibling identical SELECTs = live N+1.

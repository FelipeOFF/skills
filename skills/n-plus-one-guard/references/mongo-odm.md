# MongoDB / Document ODMs (Mongoose, Beanie, Spring Data Mongo) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

The classic document N+1: `.populate()` (Mongoose) or `findById` called **per doc in a loop**.
Document DBs have no real JOIN — the ODM fires an extra query per reference. The cure is to
batch (`$in`/`$lookup`) in one round-trip, not to access the reference per item.

## Detect — runtime

**Fail-at-point first.** None of these ODMs has a `raiseload` that blows up at the exact
`file:line` of the lazy access — the Node driver is async, and Beanie/Spring resolve links
with explicit queries. The closest to fail-at-point is **counting ops in the driver and
throwing when the budget is exceeded**, placing the stack trace at the call site that fired
the extra query:

```ts
// Mongoose/Node driver — monitorCommands counts real ops; throws at the call site over budget
const client = new mongodb.MongoClient(uri, { monitorCommands: true });
let n = 0;
client.on('commandStarted', (e) => {           // 1 event per op sent to the server
  if (['find','aggregate','getMore'].includes(e.commandName) && ++n > BUDGET)
    throw new Error(`query budget exceeded at op #${n}: ${e.commandName} ${e.databaseName}`);
});
```

**Pattern-detectors / query-logging hooks** (count ops per request; flag when the **same
shape** repeats N times):

```ts
// Mongoose — debug as a CALLBACK (not bool): logs every op with collection+method+args
mongoose.set('debug', (coll, method, ...args) => {
  log.debug(`${coll}.${method}`, JSON.stringify(args[0]));   // count repeated 'find' = N+1
});
```

```python
# Beanie/Motor — PyMongo command monitoring: exact signature of the Link N+1
from pymongo import monitoring
class Counter(monitoring.CommandListener):
    def started(self, e):
        if e.command_name == 'find': log.debug('find %s', e.command.get('filter'))
beanie.init... # AsyncIOMotorClient(uri, event_listeners=[Counter()])
```

Spring Data Mongo: turn on template logging (`logging.level.org.springframework.data.mongodb.core.MongoTemplate=DEBUG`)
and count the repeated `find`s; `@DocumentReference`/`@DBRef` per property = 1 query each (N+1).

## Detect — static / lint

There's no native N+1 analyzer for these ODMs. Use structural grep (ast-grep/semgrep):

```yaml
# n-plus-one-mongo.yml — ast-grep: populate()/findById inside a loop
rule:
  any:
    - pattern: 'for ($_ of $_) { $$$; await $X.populate($$$); $$$ }'
    - pattern: 'for ($_ of $_) { $$$; await $M.findById($$$); $$$ }'
    - pattern: '$ARR.map(async ($_) => { $$$; await $M.findById($$$); $$$ })'
```

```bash
# Mongoose — populate inside loop/map (the .map case the await lint misses)
grep -rnE '\.(populate|findById|findOne)\(' src/ | grep -nE 'for |\.map\(|\.forEach\('
# Beanie — fetch_link/fetch_all_links per item (should be fetch_links=True on the query)
grep -rnE 'fetch_link\(|fetch_all_links\(' app/
# Spring — @DBRef/@DocumentReference WITHOUT lazy and without a matching @Aggregation
grep -rnE '@DBRef|@DocumentReference' --include=*.java src/
```

ESLint core `no-await-in-loop` catches the **sequential** N+1 in TS, but not `.map(async)` —
cover that with the semgrep above (same logic as the `node-typescript.md` spoke).

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1·FK (Mongoose) | `populate()` on the QUERY (1 extra query per path, batched `$in`) | `Story.find().populate('author')` // NOT per-doc in a loop |
| 1:N (Mongoose) | `populate()` on the parent query, or `$lookup` in the aggregation | `Author.find({ _id:{ $in:ids } }).populate('books')` |
| 1:N filtered/sorted (Mongoose) | aggregation `$lookup` (JOIN on the server) | `Model.aggregate().lookup({ from:'books', localField:'_id', foreignField:'authorId', as:'books' })` |
| 1:1/1:N (Beanie) | `fetch_links=True` on the QUERY → `$lookup` in the pipeline | `await House.find(House.name=='x', fetch_links=True).to_list()` |
| 1:N (Spring) | `@Aggregation` with `$lookup` (drop `@DBRef` on the hot path) | `@Aggregation(pipeline={ "{ $lookup: { from:'book', localField:'_id', foreignField:'authorId', as:'books' } }" })` |
| M:N (Spring) | `@DocumentReference(lazy=true)` only for rare access; otherwise `$lookup` | `@DocumentReference(lazy = true) List<Tag> tags;` |

**Cartesian trap (1:N):** `$lookup` brings the children array **embedded in the parent doc**
(without multiplying rows like a SQL JOIN), but adding `$unwind` after recreates the Cartesian
product and **breaks `skip`/`limit`/pagination**. For paginated 1:N, prefer the paginated
parent query + `populate`/`$in` in 2 steps, not `$lookup` + `$unwind`.

## Guardrail — query-count test assertion

Count ops via command monitoring; assert **MAX, not exact** (handshakes/`getMore`/index ops
make an exact budget flaky):

```ts
// Mongoose (Jest/Vitest) — counts real finds via commandStarted
let ops: string[] = [];
beforeEach(() => { ops = []; mongoose.connection.getClient()
  .on('commandStarted', e => e.commandName === 'find' && ops.push(e.command.collection)); });
test('list endpoint not N+1', async () => {
  await Author.find().populate('books');     // seed: >1 author, >1 book each
  expect(ops.length).toBeLessThanOrEqual(2); // MAX: 1 authors + 1 books batched
});
```

```python
# Beanie — reuse the Counter (CommandListener) and assert the budget
def test_no_n_plus_one():
    Counter.finds = 0
    await House.find(fetch_links=True).to_list()   # seed >1 house, >1 link each
    assert Counter.finds <= 2                       # constant, not 1 + N
```

**CONSTANT-vs-N:** run with a **small AND large** fixture. If the count **doesn't change** as
N grows, it's cured. With 1 doc, both the N+1 and the cure give ~2 ops and the test passes
falsely.

## Stack gotchas

- **Mongoose `populate()` on the query is NOT N+1; per-doc in a loop IS.** The query-level
  version does **1 extra query per path** (batched `$in`), regardless of the number of parent
  docs. `doc.populate()` repeated inside a `for`/`map` is the N+1 — same API, opposite cost.
- **`mongoose.set('debug', true)` (bool) only prints;** pass a **function** to count/assert.
  Reliable op counting is in the driver (`monitorCommands`), not the colored log.
- **`mongoose-autopopulate` hides N+1:** it populates on every `find` automatically — including
  in loops and nested sub-docs, multiplying queries invisibly in review. Prefer explicit
  per-query `populate`.
- **`populate` with `perDocumentLimit` makes 1 query PER doc** (a deliberate N+1); the normal
  `limit` applies `numDocs * limit` in a single query. Know which one you're using.
- **Beanie: `fetch_links=True` on the query uses `$lookup`; `fetch_link()`/`fetch_all_links()`
  per object is N+1.** Limit depth with `nesting_depth=` (default 3) — a deeply nested link
  becomes a heavy pipeline, not a saving.
- **Spring `@DBRef`/`@DocumentReference` makes 1 query per property per doc** — guaranteed N+1
  when loading lists. `lazy=true` only defers it (and still fires on access); the real cure is
  `@Aggregation` with `$lookup`. `$lookup` **does not resolve `@DBRef`** (`{$ref,$id}` format);
  use `@DocumentReference` (stores the raw id) or model the reference as a plain field.

## LLM playbook (ordered, tool-first)

1. **Identify the ODM:** `grep -E '"mongoose"|beanie|spring-boot-starter-data-mongodb' package.json pyproject.toml pom.xml build.gradle`.
2. **Grep the doc N+1 pattern:** Mongoose `grep -rnE '\.(populate|findById|findOne)\(' src/` and cross with `for |\.map\(|\.forEach\(`; Beanie `grep -rnE 'fetch_link\(|fetch_all_links\('`; Spring `grep -rnE '@DBRef|@DocumentReference'`.
3. **Run ast-grep/semgrep** (`n-plus-one-mongo.yml`) for `populate()`/`findById()` inside `for-of` **and** `.map(async)` — `.map` is what the await lint misses.
4. **Flag `@DBRef`/`@DocumentReference` without `lazy` and without a matching `@Aggregation`** (Spring) and `mongoose-autopopulate` on the schema (Mongoose) as direct suspects.
5. **Confirm at runtime:** Mongoose `mongoose.set('debug', fn)` + driver `monitorCommands:true`/`commandStarted`; Beanie/Motor `CommandListener.started`; Spring `MongoTemplate=DEBUG`. Hit the endpoint with a seed of **>1 parent and >1 child**.
6. **Count and normalize:** if the same `find` (same collection) repeats 1× per parent doc, it's a confirmed N+1 — you have the collection and the filter in hand.
7. **Write the budget test FIRST (red):** `commandStarted` counting `find`, `expect(ops.length).toBeLessThanOrEqual(N)`, seeding >1 parent × >1 child; confirm it FAILS at ~O(docs).
8. **Apply the cure by cardinality** (table): Mongoose `find().populate()` on the query (or `$lookup`), Beanie `fetch_links=True`, Spring `@Aggregation` + `$lookup`. Pull `populate`/`fetch_link` out of loops.
9. **Re-measure:** run the test and the monitor again; the count must drop to a **small constant** (~2), not just get faster. Reject a cure via `Promise.all` of per-doc `populate` (it parallelizes N queries, doesn't batch).
10. **CI gate:** keep the op-count assertion + an advisory semgrep step. Run with small AND large fixtures to prove invariance. Watch for the `$lookup`+`$unwind` Cartesian trap in paginated 1:N.

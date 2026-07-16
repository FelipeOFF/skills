# .NET / EF Core — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Cure first: **`.Include`/`.ThenInclude`** or (read path) **DTO projection via
`Select`**; multiple collections → **`.AsSplitQuery()`** (avoids cartesian explosion).
EF Core **has no** N+1 analyzer — `Microsoft.EntityFrameworkCore.Analyzers`
ships in the package but does **not** detect N+1. Detection is runtime: log of
`Database.Command` + counting `DbCommandInterceptor` + `ConfigureWarnings` on lazy.

## Detect — runtime

**Fail-at-point (the closest the stack offers).** Make **any** lazy load
throw an exception at the access `file:line` — the #1 cause of silent N+1:

```csharp
options.ConfigureWarnings(w => w
    .Throw(CoreEventId.NavigationLazyLoading)              // lazy load => exception
    .Throw(RelationalEventId.MultipleCollectionIncludeWarning)); // cartesian
```

To pinpoint the call-site **without** banning lazy yet, the community interceptor
`LazyLoadLoggingInterceptor` logs warning+stack on every lazy load.

**Logging / counting (confirm the N+1 shape).** The canonical surface: enable
`Database.Command` at `Information` and look for the **SAME SELECT** repeated changing
only `@__p_0` (event id **20101**) — that pattern IS the N+1, count the repetitions:

```jsonc
// appsettings.json
{ "Logging": { "LogLevel": {
  "Microsoft.EntityFrameworkCore.Database.Command": "Information" } } }
// info: ...Database.Command[20101] Executed DbCommand ... WHERE [p].[BlogId] = @__p_0
```

```csharp
// request-scoped DbCommandInterceptor — counts real SQL and keeps the texts
public sealed class QueryCountInterceptor : DbCommandInterceptor {
  private int _count; public int Count => _count;
  public readonly List<string> CommandTexts = new();
  public void Reset() { _count = 0; CommandTexts.Clear(); }
  public override InterceptionResult<DbDataReader> ReaderExecuting(
      DbCommand cmd, CommandEventData e, InterceptionResult<DbDataReader> r) {
    Interlocked.Increment(ref _count); CommandTexts.Add(cmd.CommandText);
    return base.ReaderExecuting(cmd, e, r); } }
// options.AddInterceptors(scopedCounter); read/assert _count at end of pipeline
```

EF Core 9+: `dotnet counters monitor --counters Microsoft.EntityFrameworkCore -p <PID>`
(`microsoft.entityframeworkcore.queries` instrument); spike proportional to rows = N+1.

## Detect — static / lint

**There is no maintained N+1 analyzer.** `jumpinjackie/roslyn-ef-linq-analyzer`
is **archived** (Jan 2020, EF6-only). Don't recommend a magic analyzer.

```text
// BannedSymbols.txt  (with Microsoft.CodeAnalysis.BannedApiAnalyzers)
M:Microsoft.EntityFrameworkCore.ProxiesExtensions.UseLazyLoadingProxies(Microsoft.EntityFrameworkCore.DbContextOptionsBuilder,System.Boolean);Lazy loading causes N+1 — use Include/projection
```

```yaml
# semgrep: materializes and iterates accessing a navigation (lexical N+1 shape)
rules:
- id: efcore-possible-nplusone
  languages: [csharp]
  severity: WARNING
  patterns:
    - pattern: |
        $XS = await $Q.ToListAsync();
        ...
        foreach ($X in $XS) { ... $X.$NAV ... }
  message: Possible N+1 — check .Include($NAV) or Select projection on $Q
```

ast-grep: `ast-grep -p 'foreach ($X in $C) { $$$ $X.$NAV $$$ }' --lang csharp`,
then check whether `$C` was built **without** `.Include(` / `.Select(... => new Dto)`.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| **1:1 · FK (reference nav)** | `.Include` — single JOIN, no cartesian risk | `await db.Posts.Include(p => p.Author).ToListAsync();` |
| **1:1/FK + 1:N nested** | `.ThenInclude` chains deep graphs | `await db.Blogs.Include(b => b.Posts).ThenInclude(p => p.Author).ToListAsync();` |
| **1:N (one collection)** | `.Include` (1 LEFT JOIN fine for a single one) | `await db.Blogs.Include(b => b.Posts).ToListAsync();` |
| **1:N (2+ collections → cartesian)** | `.AsSplitQuery()` — 1 roundtrip per collection | `await db.Blogs.Include(b=>b.Posts).Include(b=>b.Contributors).AsSplitQuery().ToListAsync();` |
| **M:N (skip nav)** | `.Include` on the skip nav; split if other collections exist | `await db.Posts.Include(p => p.Tags).AsSplitQuery().ToListAsync();` |
| **1:N (filtered)** | Filtered `Include` — eager, 1 roundtrip, limits rows | `db.Blogs.Include(b => b.Posts.Where(p => p.IsPublished).Take(5));` |
| **read-only / DTO** | `Select` projection — 1 query, no tracking, lazy **impossible** | `await db.Blogs.Select(b => new BlogDto { Url=b.Url, Titles=b.Posts.Select(p=>p.Title).ToList() }).ToListAsync();` |

**Cartesian JOIN trap (1:N):** **two+** collections in `Include` **multiply**
rows (1 parent × N × M). `.AsSplitQuery()` splits each collection into a roundtrip — but it's
the cure for the **cartesian**, NOT the N+1; don't confuse them. For the read path, prefer
DTO projection: lazy loading doesn't exist over a projection.

## Guardrail — query-count test assertion

```csharp
counter.Reset();                       // REQUIRED before the Act
await sut.GetBlogsWithPosts();
Assert.True(counter.Count <= 2,        // MAX, not EXACT
    $"N+1: {counter.Count} queries\n{string.Join("\n", counter.CommandTexts)}");
```

More robust than a flat cap — **group by SQL shape** (the same SELECT repeated
is N+1 even under a generous cap):

```csharp
var dup = counter.CommandTexts
    .GroupBy(Normalize)                 // strip parameter literals
    .Where(g => g.Count() > 3);
Assert.Empty(dup);                      // same SELECT repeated => N+1
```

In integration (`WebApplicationFactory`): register the test DbContext with
`ConfigureWarnings(w => w.Throw(CoreEventId.NavigationLazyLoading))` — an endpoint
with lazy load fails with `InvalidOperationException`.

Use **MAX, not EXACT** (warmup/prepare jitter the exact count). And run with a
**small AND large** fixture: a good cap is **constant** — N=10 and N=1000 give the same
count. A cap that only passes at N=1 hides the bug.

## Stack gotchas

- **False cure: `.Include` with lazy loading ON doesn't fix it** if the code
  accesses a **non-included** nav — the lazy load fires anyway. Banning lazy or
  `Throw(CoreEventId.NavigationLazyLoading)` is the only way to guarantee it.
- **`AsSplitQuery` cures the CARTESIAN, not N+1.** Each split is a separate
  roundtrip — over-splitting looks like "too many queries". They're distinct problems.
- **`AsNoTracking` disables identity resolution:** referencing the same Blog 100×
  materializes 100 instances (duplicated memory/data) — not N+1, but reviewers
  confuse the duplicate objects for a single one.
- **Serializing an entity straight from the controller** (System.Text.Json) triggers
  an invisible N+1: the serializer walks every navigation. Map to a DTO at the edge.
- **Projection (`Select` to a DTO) is the strongest prevention** (lazy impossible) —
  prefer it over `Include` on the read path; but it loses change tracking (don't use for updates).
- **`TagWith`/query tags** correlate SQL to the call-site in the log, but **detect**
  nothing on their own.
- **Provider matters:** `AsSplitQuery` is relational-only; Cosmos translates `Include`
  differently — don't apply the SQL Server playbook blindly.
- **Dapper:** no nav-property N+1, but a per-item loop still issues N queries; multi-
  mapping requires explicit `splitOn` (`QueryAsync(sql, map, splitOn: "Id")`).

## LLM playbook (ordered, tool-first)

1. **Lazy loading mode FIRST:** `rg -n 'UseLazyLoadingProxies|public virtual .*(ICollection|List<)' --type cs`. Lazy on = high risk, prime suspect.
2. **Structural smell:** `rg -n 'ToListAsync|ToList\(\)' --type cs -A6 | rg 'foreach|\.Select\('`; for each hit check for a missing `.Include(` or `Select(... => new Dto)` in the chain.
3. **ast-grep:** `ast-grep -p 'foreach ($X in $C) { $$$ $X.$NAV $$$ }' --lang csharp`; flag where `$C` was built without `.Include($NAV)`.
4. **Make it noisy:** in the DbContext (or test host) `ConfigureWarnings(w => w.Throw(CoreEventId.NavigationLazyLoading).Throw(RelationalEventId.MultipleCollectionIncludeWarning))`.
5. **EF log at Information** for `Microsoft.EntityFrameworkCore.Database.Command`, exercise the endpoint 1×, grep the SAME SELECT repeated changing only `@__p_0` (event 20101) — count the repetitions.
6. **`QueryCountInterceptor`** (DbCommandInterceptor.ReaderExecuting) request-scoped; log count + normalized SQL shapes via middleware. A count that scales with rows = N+1 confirmed.
7. **Integration test** (`WebApplicationFactory`): assert (a) `counter.Count <= expected` AND (b) no normalized shape repeats >3×. Lock it in CI.
8. **Rider/ReSharper available?** Run the flow under Dynamic Program Analysis (DPA) and read "repeated database queries" to nail the call-site.
9. **Manual/dev repro:** MiniProfiler (`.AddEntityFramework()`), open `/profiler/results` — a red 'duplicate' badge confirms the query fired N×.
10. **Cure by priority:** (a) `Select` to a DTO (kills N+1 and lazy); else (b) `.Include(...).ThenInclude(...)`; multiple collections → `.AsSplitQuery()`; (c) ban lazy via BannedApiAnalyzers (`UseLazyLoadingProxies`).
11. **PROVE the drop** by re-running 5/7 (N+1 → 1 or 2). Don't declare it resolved without recounting — `Include` with lazy still on is a common false cure.

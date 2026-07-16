# Elixir / Ecto — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Crucial difference: **Ecto does NOT lazy-load.** Accessing an unloaded association
does not fire a query — it returns `%Ecto.Association.NotLoaded{}`. So the N+1 here is
**explicit**: an `Enum.map`/`for` with `Repo.*` per item, or a GraphQL resolver per
node. The foundation of all runtime detection is the telemetry event `[:my_app, :repo, :query]`
(emitted once per query). Targets: Ecto 3.12+, Absinthe 1.7.x, dataloader 2.x.

## Detect — runtime

**Fail-at-point first — the `NotLoaded` crash IS already fail-fast.** Since Ecto doesn't
lazy-load, accessing `post.comments` without preload raises `KeyError`/`Protocol.UndefinedError`
at the exact `file:line` of the access (it doesn't become a silent query). Make the intent
explicit by asserting the preload — `EctoRequireAssociations.ensure!/2` (lib `ecto_require_associations`,
same syntax as `preload`) or the native `Ecto.assoc_loaded?/1`:

```elixir
# native, zero deps — guard at the boundary before serializing
true = Ecto.assoc_loaded?(post.comments) or raise "comments not preloaded"
# or with the lib (same preload syntax, nested):
EctoRequireAssociations.ensure!(post, [comments: :author])  # raise if missing
```

Pattern-detector / query-logging (hunts repeated identical SELECTs): in dev use
`ecto_dev_logger` (`Ecto.DevLogger.install(MyApp.Repo)` in Application; turn off the Repo's
default logger in config) — inlines the binds, easy to spot the repeated query.
To COUNT, attach a handler on the query event:

```elixir
:telemetry.attach("count", [:my_app, :repo, :query], fn _e, _m, meta, pid ->
  if meta.source, do: send(pid, {:q, meta.source})  # ignore begin/commit (source=nil)
end, self())
```

`meta` carries `:source`, `:query`, `:params`, `:result`, `:stacktrace` (enable
`stacktrace: true` in Repo.config to see the `file:line` that originated the query).

## Detect — static / lint

There is no official first-party rule. **Custom Credo check** is the idiomatic path: there's
`oeditus_credo` (3rd-party, verify maintenance before adopting) with `NPlusOneQuery`
(`Enum.map` containing `Repo.*`) and `MissingPreload`. Sobelow is **security only**, doesn't catch
N+1. Dep-independent backstop with grep/ast-grep:

```bash
# Repo.* inside Enum.map/for/Enum.each — strong N+1 candidate
grep -rnE 'Enum\.(map|each|flat_map|reduce)|[^.]\bfor\b' lib/ \
  | grep -E 'Repo\.(get|get_by|one|all|preload|aggregate)'
# ast-grep: Repo.* nested in Enum.map
ast-grep -l elixir -p 'Enum.map($_, fn $_ -> $$$ Repo.$M($$$) $$$ end)' lib/
```

## Fix — eager idioms by cardinality

`Repo.preload` = ALWAYS 2 queries (1 parent + 1 `WHERE id IN (...)`), batched, the norm.
`join: assoc()` + `preload:` = 1 query with JOIN, **only** when you need to filter/order
by the association. `Ecto.assoc(structs, :x)` builds the association query for a list.

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1 · FK (`belongs_to`/`has_one`) | simple `preload`, or `join: assoc` if filtering | `Repo.all(from u in User, preload: [:profile])` |
| 1:N (`has_many`) | `Repo.preload` / `preload:` keyword (2 queries, NOT JOIN) | `Repo.all(from p in Post, preload: [:comments])` |
| 1:N filtered | `join: assoc(...)` + `preload: [k: binding]` (custom query) | `from p in Post, join: c in assoc(p, :comments), where: c.flagged, preload: [comments: c]` |
| 1:N with custom query | `Repo.preload` with `{query, nested}` | `Repo.preload(posts, comments: {from(c in Comment, order_by: c.inserted_at), [:author]})` |
| M:N (`many_to_many`) | `Repo.preload` (resolves the join table itself) | `Repo.preload(users, [:roles])` |
| nested | nested list/keyword in a single load | `Repo.preload(posts, [comments: [:author, :likes]])` |

**Cartesian JOIN trap:** for 1:N, `join: assoc` + `preload` in a single query
**multiplies rows** (1 parent × N children) and **breaks `limit:`/pagination** — the `LIMIT`
cuts children, not parents. Use JOIN only to FILTER; to just load, go with `preload`
(2 queries). Counts: `Repo.aggregate`/subquery, never `length(post.comments)` in a loop.

## Guardrail — query-count test assertion

No stable dedicated lib: the idiom is to attach telemetry and count. **Use MAX, not EXACT**
(Sandbox begin/commit/savepoint inflate the exact count and make it flaky). Filter `meta.source == nil`
(transactions). Run with a **small AND large** fixture — N+1 is when the count GROWS
with N; a good budget is CONSTANT.

```elixir
defp count_queries(fun) do
  ref = make_ref()
  :telemetry.attach({ref, self()}, [:my_app, :repo, :query], fn _e, _m, meta, {r, pid} ->
    if meta.source, do: send(pid, {r, :q})
  end, {ref, self()})
  fun.()
  :telemetry.detach({ref, self()})
  Stream.repeatedly(fn -> receive do {^ref, :q} -> :q after 0 -> nil end end)
  |> Enum.take_while(& &1) |> length()
end

test "post list is O(1) in queries" do
  insert_list(2, :post_with_comments)
  small = count_queries(fn -> Blog.list_posts() end)
  insert_list(20, :post_with_comments)
  large = count_queries(fn -> Blog.list_posts() end)
  assert small == large and large <= 3   # CONSTANT, doesn't grow with N
end
```

## Stack gotchas

- **`join:` without `preload:` does NOT load the association** — it only filters. Accessing `p.comments`
  afterward still gives `NotLoaded`. JOIN eager-loads only with a matching `preload:` keyword.
- **`preload` + `limit:` in the SAME query with JOIN cuts the wrong children** (LIMIT applies
  on the already-joined table). Paginate the parent with `preload` in 2 queries, not with JOIN+limit.
- **Silent re-preload:** `Repo.preload` on an already-loaded struct does **not** re-fetch
  (cached in memory); pass `force: true` if the data changed. Inverse: preload in a per-item loop
  ignores the batch — preload ONCE on the whole list.
- **`Repo.preload` on a single struct = N queries if called per item.** Batching only exists
  when you pass the LIST of parents at once (`Repo.preload(all_posts, :comments)`).
- **GraphQL/Absinthe is the #1 place for N+1** (resolver runs per node). `absinthe_ecto` is
  **DEPRECATED** — use Dataloader: `Dataloader.Ecto.new(Repo)` as source, plugin
  `Absinthe.Middleware.Dataloader`, and `resolve: dataloader(Source)` on the field. The Dataloader
  instance goes in the **per-request context** (a singleton leaks cache across users).
- **Test Sandbox pollutes the count:** `begin`/`commit`/`savepoint` emit a query event
  with `source: nil` — filter them out or you'll count phantom N+1.

## LLM playbook (ordered, tool-first)

1. **Identify versions:** `grep -E ':ecto|:absinthe|:dataloader|:ecto_dev_logger' mix.exs` and confirm `mix deps | grep -E 'ecto|dataloader'`.
2. **Grep query-in-loop (no DB):** `grep -rnE 'Enum\.(map|each|flat_map|reduce)|\bfor\b' lib/ | grep -E 'Repo\.(get|get_by|one|all|preload|aggregate)'` — each hit is a candidate.
3. **Grep GraphQL fan-out:** `grep -rnE 'resolve.*Repo\.' lib/**/schema*.ex lib/**/*resolver*` — resolver calling Repo directly = N+1 per node; should use `dataloader(...)`.
4. **Fail-at-point:** run the suspect flow; if it raises `NotLoaded`/`KeyError` on an assoc access, that's the `file:line` of the latent N+1. Reinforce with `Ecto.assoc_loaded?/1`/`ensure!`.
5. **Query log in dev:** `Ecto.DevLogger.install(MyApp.Repo)` (turn off default logger in config) → exercise the endpoint → look for the SAME SELECT repeated N times.
6. **Counter in the test:** attach `:telemetry` on `[:my_app, :repo, :query]` (filter `source==nil`), `count_queries/1` above, on the suspect function.
7. **Prove it FAILS today** (count grows with N), then fix via the idiom: `Repo.preload`/`preload:` for 1:N and M:N; `join: assoc` + `preload:` only to filter; Dataloader for Absinthe.
8. **Re-measure** with a small AND large fixture: `assert small == large and large <= budget` — a CONSTANT count proves the fix.
9. **Gate in CI:** keep the count test in the suite; optional `credo` custom check (`NPlusOneQuery`/`MissingPreload`) as a fast PR lint.
10. **Prod:** `opentelemetry_ecto` (`OpentelemetryEcto.setup`) → read the waterfall of a list-endpoint; N sibling spans of the same SQL under one parent = live N+1.

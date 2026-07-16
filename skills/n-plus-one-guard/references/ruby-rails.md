# Ruby on Rails / ActiveRecord — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Foundation for everything: each query fires `sql.active_record` (`ActiveSupport::Notifications`).
Every runtime/test detector here relies on this. Target versions: Rails 7.1–8.0,
bullet 8.x, prosopite 2.x, n_plus_one_control 0.8.0.

## Detect — runtime

**Fail-at-point first — `strict_loading` (native, no gem, Rails 6.1+).** Any
lazy association access raises `ActiveRecord::StrictLoadingViolationError` at the
exact `file:line`. It's the native first-class guard — prefer it over add-ons.

```ruby
# config/environments/development.rb / test.rb
config.active_record.strict_loading_by_default = true
config.active_record.action_on_strict_loading_violation = :raise # or :log to triage first
# Granular opt-in instead of global:
User.strict_loading.find(id)              # relation
user.strict_loading!                      # single record
has_many :comments, strict_loading: true  # per association
```

**`prosopite` (2.x, active) — pattern-based detector, zero false +/-.** Fingerprints
call-stack + query, unlike `bullet` which false-positives. Prefer it over bullet.

```ruby
# Gemfile (dev/test): gem 'prosopite'; gem 'pg_query'  # pg_query for Postgres
Prosopite.raise = true          # N+1 becomes an exception
Prosopite.rails_logger = true
Prosopite.allow_list = ['active_storage'] # silence known cases
# application_controller.rb
unless Rails.env.production?
  around_action { |_c, b| Prosopite.scan; b.call ensure Prosopite.finish }
end
```

`bullet` (8.x) also detects unused eager loading and missing counter_cache, but
needs `Bullet.add_safelist` for false positives — use only one per env (prosopite in
test/CI). `rack-mini-profiler` (below pg/mysql2 in the Gemfile) shows a badge with
SQL count, duplicates, and the source line; `?pp=flamegraph` for the call path.

## Detect — static / lint

No RuboCop cop nor official Semgrep rule exists for N+1 (data-flow isn't statically
decidable) — don't invent one. Use the "loop over relation without
`.includes/.preload/.eager_load`" heuristic as a **hint**, confirm with prosopite/strict_loading.

```yaml
# rails-n-plus-one.yml — semgrep --config rails-n-plus-one.yml app/
rules:
  - id: rails-each-without-includes
    languages: [ruby]
    severity: WARNING
    message: Possible N+1 — association access in loop without includes/preload
    patterns:
      - pattern: $REL.each do |$X| ... $X.$ASSOC ... end
      - pattern-not: $REL.includes(...).each do |$X| ... end
```

`rubocop-rails` only helps with adjacent smells (`Rails/FindEach`, `Rails/Pluck`), not
real N+1. `ast-grep` is the faster CI equivalent: `sg run -p '$A.each { |$I| $$$ $I.$ASSOC $$$ }' -l ruby app/`.

## Fix — eager idioms by cardinality

`.includes` lets AR choose preload vs eager_load. `.preload` = always 2 separate
queries (can't filter on the association). `.eager_load` = forces LEFT OUTER JOIN in one query.
`.joins` does **NOT** eager-load (only filters) — accessing the relation afterward is still N+1.

| Relation | Idiom | Snippet |
|---|---|---|
| 1:1 / FK (`belongs_to`/`has_one`) | `.includes`; `.eager_load` if filtering/ordering on the table | `Comment.eager_load(:author).where(authors: { active: true })` |
| 1:N (`has_many`) | `.includes` or `.preload` (avoids cartesian JOIN that **breaks LIMIT**) | `Post.preload(:comments)` |
| 1:N filtered | `.includes` alone degrades to N+1 — add `.references` (or `.eager_load`) | `Post.includes(:comments).where(comments: { flagged: true }).references(:comments)` |
| M:N (`has_many :through`/HABTM) | nested hash in a single load | `User.includes(posts: [:comments, :tags])` |
| Polymorphic / STI | `.preload` (can't JOIN across types) | `Comment.preload(:commentable)` |

**Cartesian trap:** `.eager_load`/JOIN on 1:N multiplies rows (1 parent × N children) and
breaks pagination — use `.preload` (2 queries). Counts in a loop: use `counter_cache: true`
on `belongs_to`, not `.size`/`.count`.

## Guardrail — query-count test assertion

**Preferred: `n_plus_one_control` (0.8.0) — tests CONSTANT-vs-N, not a fixed ceiling.** Runs
the block at multiple scales (n=2,3) and asserts O(1). It's the most robust gate: a fixed
ceiling passes with N=1 and hides the bug.

```ruby
# spec/requests/posts_spec.rb
context 'N+1', :n_plus_one do
  populate { |n| create_list(:post, n) }   # SCALE the data — otherwise false green
  specify { expect { get '/posts' }.to perform_constant_number_of_queries }
end
# Minitest: assert_perform_constant_number_of_queries { get posts_url }
```

Budget pin on a hot endpoint (Rails 7.2+, native). Prefer **MAX**, not exact —
exact counts flake with auth/savepoint/warmup.

```ruby
include ActiveRecord::Assertions::QueryAssertions
assert_queries_count(3) { get posts_url }   # 1 posts + 1 comments + 1 users
assert_no_queries { Current.config }
```

Rails <7.2: manual counter over `sql.active_record`, **excluding** CACHE/SCHEMA/TX
(see `request_query_counter` below).

## Stack gotchas

- `strict_loading_by_default = true` breaks on ActiveStorage attachments and some
  `has_one`/polymorphics (rails#54751) — allow-list/scope instead of flipping global on day 1.
- `.includes` + `.where(assoc: ...)` **without** `.references` degrades silently to
  N+1 (or "missing FROM-clause") — `.references` or `.eager_load` fix it.
- `.includes` that never reads the association = unused eager loading (bullet warns); waste.
- Polymorphic/STI can't `.eager_load` (JOIN) across types — only `.preload`, else raise/N+1.
- GraphQL/serializer N+1 is invisible to `.includes` at the controller root (resolvers
  load lazily per node) — use `graphql-batch` or `ar_lazy_preload`, not eager at the root.
- Running bullet **and** prosopite in the same env duplicates reports and slows the suite —
  one per env (prosopite test/CI, rack-mini-profiler dev).
- Counters must exclude CACHE/SCHEMA/TRANSACTION and (7.1+) async/leasing queries,
  else they go flaky (`assert_queries_count` uses `include_schema: false` for this).

## LLM playbook (ordered, tool-first)

1. **Detect version/ORM:** `bundle list | grep -E 'rails|bullet|prosopite|n_plus_one_control'`; read `config/application.rb` (gates strict_loading + QueryAssertions).
2. **Inventory guards:** `grep -rE 'Bullet\.(enable|raise)|Prosopite\.(scan|raise)|strict_loading|perform_constant_number_of_queries|assert_queries_count' config/ spec/ test/ app/`.
3. **Static (cheap, noisy):** `grep -rnE '\.(each|map|flat_map|sum)\b' app/` and, on each hit, check for `.includes(`/`.preload(`/`.eager_load(` in the same chain. Optional: Semgrep/ast-grep rule above.
4. **Fail-at-point:** turn on `strict_loading_by_default = true` (action `:raise`) in dev/test — catches the exact `file:line` of the lazy access. Allow-list ActiveStorage.
5. **Confirm the pattern:** install `prosopite` (+ `pg_query`), `Prosopite.raise = true`, `around_action` with `Prosopite.scan`/`finish` on the suspect action — zero false positives.
6. **Reproduce visually in dev:** `rack-mini-profiler` (below pg/mysql2), open the badge → SQL count + duplicates + source line; `?pp=flamegraph`.
7. **CI gate (preferred):** `gem 'n_plus_one_control'`; request spec `:n_plus_one` with `populate { |n| create_list(...) }` and `perform_constant_number_of_queries` — fails when it grows with N.
8. **Budget pin:** `include ActiveRecord::Assertions::QueryAssertions`; `assert_queries_count(N) { get path }` (7.2+) or manual counter over `sql.active_record`.
9. **Suite-wide net (optional):** `Prosopite.scan`/`finish` in `before/after(:each)` of `rails_helper` with `raise = true`; seed `allow_list` with current offenders and ratchet down.
10. **Fix with the right idiom** (table above) and **re-measure** (steps 5/7): confirm the count dropped, that `.where(assoc)` has `.references`, and that you didn't mistake `.joins` for eager loading.

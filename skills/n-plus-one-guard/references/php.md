# PHP (Laravel Eloquent + Doctrine) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Identify the ORM first: `extends Model` / `Illuminate\Database\Eloquent`
= Eloquent; `#[ORM\Entity]` / `Doctrine\ORM` = Doctrine. Check versions in
`composer.json` (`laravel/framework`, `doctrine/orm`, `doctrine/dbal`).

## Detect — runtime

**Fail-at-point first (Eloquent).** `Model::preventLazyLoading()` throws
`LazyLoadingViolationException` at the exact `file:line` of the lazy access — the best
detector. Off in prod by default (guard dev/CI only).

```php
// AppServiceProvider::boot()
use Illuminate\Database\Eloquent\Model;

Model::preventLazyLoading(! $this->app->isProduction());
// or all guards at once (lazy + missing/discarded attribute):
Model::shouldBeStrict(! $this->app->isProduction());
```

**Pattern detector (Eloquent).** `beyondcode/laravel-query-detector` counts
repeated relations; register the `Throw_` output in the test env to fail the request.

```php
// config/querydetector.php
'threshold' => 1,
'output' => [\BeyondCode\QueryDetector\Outputs\Throw_::class], // throws QueryDetectorException
```

**Visual (dev only).** Telescope `/telescope` → Queries flags identical repeated
query as `duplicate` (= N+1, with caller). `barryvdh/laravel-debugbar` with
`'show_duplicates' => true` + `'backtrace' => true` in the Queries panel.

**Doctrine.** `SQLLogger`/`DebugStack` are DEPRECATED (DBAL 3) / REMOVED (DBAL 4)
— use a logging `Middleware` that counts queries. On Symfony, the profiler `db`
collector already counts. Add-on: `danydev/doctrine-n-plus-one-detector` (dev/test).

```php
use Doctrine\DBAL\Logging\Middleware;
use Psr\Log\AbstractLogger;

$counter = new class extends AbstractLogger {
    public int $count = 0;
    public function log($level, $message, array $context = []): void {
        if (str_starts_with((string) $message, 'Executing')) $this->count++;
    }
};
$config->setMiddlewares([new Middleware($counter)]); // on the ORM Configuration
```

## Detect — static / lint

- **Larastan** (`larastan/larastan`, ex-`nunomaduro/`) has no N+1 rule, but at
  high level it keeps relation types correct so review can spot loops over a relation.
- **Semgrep (Eloquent):** `foreach` reading `$item->relation` without `->with(...)` first.
  High recall, triage with the query-detector.

```yaml
# eloquent-nplus1-loop.yml
rules:
  - id: eloquent-nplus1-loop
    languages: [php]
    severity: WARNING
    message: foreach over query result accesses relation without with()/load()
    patterns:
      - pattern: 'foreach ($COLL as $ITEM) { ... $ITEM->$REL ... }'
      - pattern-not-inside: '$X->with(...); ...'
```

- **Semgrep (Doctrine):** ban `fetch: EAGER` on `OneToMany`/`ManyToMany` (false
  cure — see Gotchas) and require `JOIN FETCH`.
- **ast-grep (Doctrine):** `$REPO->find($ID)` inside `foreach_statement` = per-item
  fetch; batch with `findBy([... IN ...])` or DQL `JOIN FETCH`.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| **1:1 / FK** (Eloquent) | `belongsTo`/`hasOne` eager, nested | `Post::with(['author', 'author.profile'])->get();` |
| **1:N** (Eloquent) | `with()` → 2 queries (users + posts via `IN`) | `User::with('posts')->get();` |
| **M:N** (Eloquent) | `belongsToMany` + constraint + count | `User::with(['roles' => fn ($q) => $q->where('active', 1)])->withCount('roles')->get();` |
| **1:N post-fetch** (Eloquent) | lazy-eager on an existing collection | `$users = User::all(); $users->load('posts.comments');` |
| **1:1 / FK** (Doctrine) | `ManyToOne`/`OneToOne` `fetch=EAGER` (safe on the to-one side) | `#[ORM\ManyToOne(fetch: 'EAGER')] private ?Author $author;` |
| **1:N** (Doctrine) | DQL `JOIN FETCH` — **NOT** `fetch=EAGER` | `$em->createQuery('SELECT a, b FROM App\Entity\Author a JOIN a.books b')->getResult();` |
| **M:N** (Doctrine) | DQL `JOIN FETCH` | `$em->createQuery('SELECT u, r FROM App\Entity\User u JOIN u.roles r')->getResult();` |
| **1:N** (Doctrine, QB) | `addSelect` = fetch-join | `$qb->select('a','b')->from(Author::class,'a')->leftJoin('a.books','b')->addSelect('b');` |

**Cartesian trap (1:N):** `JOIN FETCH` on a collection multiplies rows (1 parent × N
children). Doctrine **forbids** fetch-joining two `ToMany` with pagination. In Eloquent
`with()` is already 2 queries (`IN`), no cartesian — prefer it over a manual JOIN.

## Guardrail — query-count test assertion

Assert a **CONSTANT** count, not an exact one: run with a small and a large fixture; if
the count grows with N, it's N+1.

```php
// Laravel — built-in (caution: expectsDatabaseQueryCount is EXACT/brittle)
User::factory()->count(20)->hasPosts(5)->create();
$this->expectsDatabaseQueryCount(2);          // users + posts; 1 extra = N+1
$this->get('/users')->assertOk();
```

Prefer a CEILING (max) and the efficiency detector from
`mattiasgeniar/phpunit-query-count-assertions` (supports Eloquent + Doctrine):

```php
use Mattiasgeniar\PhpunitQueryCountAssertions\AssertsQueryCounts;
// ... use AssertsQueryCounts;
$this->trackQueries();
User::with('posts')->get()->each(fn ($u) => $u->posts->count());
$this->assertQueryCountLessThan(3, fn () => null);
$this->assertQueriesAreEfficient();           // fails on N+1/duplicates
```

```php
// Symfony — profiler db collector (max + token for debug)
$client->enableProfiler();
$client->request('GET', '/users');
$p = $client->getProfile();
$this->assertLessThan(5, $p->getCollector('db')->getQueryCount(),
    sprintf('N+1? token %s', $p->getToken()));
```

## Stack gotchas

- **`fetch=EAGER` on `*ToMany` (Doctrine) does NOT cure N+1** — Doctrine still emits 1
  query per parent collection. Only `JOIN FETCH` (or QB `->leftJoin()->addSelect()`)
  hydrates in 1 query. `fetch=EAGER` is safe only on `ManyToOne`/`OneToOne`.
- **`preventLazyLoading()` is off in prod by default.** Guard dev/CI; it won't catch N+1 in
  production unless you opt in (risky — one accidental lazy access tanks the request).
- **`expectsDatabaseQueryCount` is EXACT.** Breaks when the framework adds 1 internal
  query; use `assertQueryCountLessThan`/between for a ceiling, exact only on hot paths.
- **N+1 lives in Resources/Blade.** Accessing `$model->relation` in a `JsonResource` or
  `@foreach` triggers per-item lazy even with a clean controller — measure the count at the
  HTTP layer, not in the query builder.
- **Eager-loading the wrong relation is a false cure.** `with('a')` while the loop reads `->b`
  is still N+1 on `b`. Confirm in Telescope/Debugbar the relation ACTUALLY accessed.
- **Automatic eager loading (Laravel 12.8+) is BETA** (`Model::automaticallyEagerLoadRelationships()`)
  — loads on access, can MASK a missing `with()` (keep the count test) and has edge cases
  with `withDefault()`.
- **Don't measure with Telescope/Debugbar on** — they add their own queries; never base a CI
  count on an app with Telescope on, never in prod.

## LLM playbook (ordered, tool-first)

1. **Identify the ORM:** `rg -n 'extends Model|Illuminate\\Database\\Eloquent' app` vs
   `rg -n '#\[ORM\\Entity\]|Doctrine\\ORM' src`; pin versions in `composer.json`.
2. **Structural grep (Eloquent):** `rg -n '::all\(\)|->get\(\)' app` and check each call
   site for `->with(...)` first; flag `foreach` whose body does `$item->relation`.
3. **Structural grep (Doctrine):** `rg -n 'fetch:\s*["\x27]?EAGER' src` on `*ToMany`
   (false cure) and `rg -n '->find\(|->findOneBy\(' src` inside `foreach`.
4. **Semgrep:** `semgrep --config eloquent-nplus1-loop.yml --config doctrine-eager-collection-false-cure.yml .`
   for `file:line` candidates; triage whitelist.
5. **Turn on fail-at-point (Eloquent):** `Model::preventLazyLoading(! app()->isProduction())`
   in `AppServiceProvider::boot`, run the suite — each exception points at the missing eager.
6. **Install the detector:** `composer require --dev beyondcode/laravel-query-detector`,
   `threshold=1` + `Throw_` output in the test env; hit the suspect endpoints.
7. **Add the ceiling test:** seed N parents × M children and assert a CONSTANT count
   (`expectsDatabaseQueryCount` / `assertQueryCountLessThan` / Symfony db collector);
   raise N and re-run — if it grows, it's N+1.
8. **Inspect visually:** Telescope Queries (`duplicate` tag) or Debugbar (`show_duplicates`)
   / Symfony Web Profiler `db` to read the repeated SQL and the calling line.
9. **Fix with the right idiom:** Eloquent `->with()`/`->load()`/`$with`/`withCount`;
   Doctrine DQL `JOIN FETCH` or QB `->leftJoin()->addSelect()`. Doctrine collection: NEVER
   `fetch=EAGER`.
10. **Verify the cure:** re-run the test (constant), zero duplicates in Telescope/Debugbar,
    confirm you loaded the ACCESSED relation (not a sibling); watch for cartesian blow-up.
11. **Lock the ceiling:** request-scoped counter via `DB::listen` (or Doctrine middleware /
    db collector) that fails the test when it exceeds `MAX_QUERIES_PER_REQUEST`.
12. **Batch service calls:** `rg -n 'Http::get|->request\(' app` inside `foreach`
    (HTTP N+1) → `Http::pool` / `IN(...)` fetch / DataLoader-style.

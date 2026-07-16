# Detection Playbook (language-agnostic)

How an LLM/agent **detects N+1 with tooling** in an arbitrary repo, before
reasoning about the code by eye. Follow in order; stop as soon as a detector
confirms the problem, but always finish at Step D (guardrail).

## A — Identify the stack (1 min)

Find the ORM/driver to pick the right reference:

| Signal in repo | Stack | Reference |
|---|---|---|
| `manage.py`, `settings.py`, `models.py` | Django | `python.md` |
| `from sqlalchemy`, `sessionmaker`, `declarative_base` | SQLAlchemy | `python.md` |
| `schema.prisma`, `@prisma/client` | Prisma | `node-typescript.md` |
| `data-source.ts`, `@Entity()` (TS) | TypeORM | `node-typescript.md` |
| `sequelize`, `.belongsTo(` | Sequelize | `node-typescript.md` |
| `drizzle.config`, `drizzle-orm` | Drizzle | `node-typescript.md` |
| `Gemfile` + `ApplicationRecord` | Rails / ActiveRecord | `ruby-rails.md` |
| `@Entity` (Java) + `pom.xml`/`build.gradle` | Hibernate/JPA | `java-spring.md` |
| `gorm.io/gorm`, `ent.` | Go | `go.md` |
| `extends Model` (PHP), `composer.json` | Laravel Eloquent | `php.md` |
| `EntityManager`, `Doctrine\ORM` | Doctrine | `php.md` |
| `DbContext`, `Microsoft.EntityFrameworkCore` | EF Core | `dotnet.md` |
| `buildSchema`, `resolvers`, `@Resolver` | GraphQL | `graphql-dataloader.md` |

Quick command (adapt to the repo's dependency manager):

```bash
# Detect ORMs by declared dependency (adjust files to the ecosystem)
grep -RiE "prisma|typeorm|sequelize|drizzle-orm|sqlalchemy|django|gorm|eloquent|doctrine|hibernate|entityframework|activerecord" \
  package.json requirements.txt pyproject.toml go.mod composer.json pom.xml build.gradle Gemfile *.csproj 2>/dev/null
```

## B — Locate candidates by structural reading (grep/ast-grep)

N+1 has a syntactic signature: **relation access or I/O inside a loop**.
Find candidates without running:

```bash
# Textual heuristic: attribute/method access inside for/map/forEach
# (high recall, validate later with a runtime detector)
grep -RnE "for |\.map\(|\.forEach\(|while " src/ \
  | grep -vE "test|spec"     # 1) find the loops
# In each loop, look for: .relation, await repo.find, requests.get, fetch(, http.get
```

More precise with **ast-grep** (structural, not textual). Examples in
`static-analysis.md`. Mental pattern: "inside a loop body there is a call that
touches the DB/network (`.save`, `.find`, `select`, `fetch`, `get`)".

Latent N+1 signals worth a dedicated grep:
- Eager loading **absent** near a loop: no `select_related`/`include`/
  `with`/`Preload`/`JOIN FETCH` before iterating and accessing a relation.
- Lazy loading **enabled** (Hibernate `FetchType.LAZY`, EF Core lazy proxies,
  Eloquent default) + relation access in template/serializer/loop.
- Serializer/resolver accessing `obj.relation` per item.

## C — Confirm at runtime (runtime detector)

Static reading has false positives. **Confirm by running** the path with a
detector that counts/pinpoints queries. By stack (details in the reference):

| Stack | Enable the detector | What to watch |
|---|---|---|
| Django | `nplusone` in test settings; or `CaptureQueriesContext` | repeated-relation warning; `len(connection.queries)` |
| SQLAlchemy | `lazy="raise"` / `raiseload("*")` on load | exception exactly at the N+1 point |
| Prisma | `prisma.$on("query", e => count++)` | per-request count explodes with N |
| TypeORM/Sequelize | `logging: true` / counter in logger | `SELECT` count grows with N |
| Rails | `bullet` (alert) or `prosopite` (pattern detection) | "N+1 detected" with the association |
| Hibernate | `Statistics.getQueryExecutionCount()`; `show_sql` | SELECT count per request |
| Go (GORM) | `db.Logger` in Info mode; or `database/sql` wrapper | log of N identical SELECTs |
| Laravel | `Model::preventLazyLoading()` (dev/test) | throws `LazyLoadingViolationException` at the point |
| EF Core | `Database.Command` logging; `DbCommandInterceptor` | N commands per request |

**Golden runtime rule:** prefer detectors that **fail/explode at the exact
point** of the lazy access (`raiseload`, `preventLazyLoading`, `strict_loading`)
— they give you file:line, not just "there's an N+1 somewhere".

## D — Lock the guardrail (test assertion) — DON'T SKIP

Detection without a guardrail comes back in the next PR. Always finish by
installing a per-route query-ceiling assert (Step 2 of `SKILL.md`). Each stack
has its own (`assertNumQueries`, `SQLStatementCountValidator`,
`n_plus_one_control`, counter over `$on("query")`). Run the test with **N=1 and
N=large** and assert constant count.

## E — Static analysis in CI (continuous defense)

Add a Semgrep/ast-grep "DB/HTTP call inside loop" rule to CI to block the whole
problem class in new code. See `static-analysis.md`.

## Detector preference order

1. **Fail-at-point** runtime (`raiseload`, `preventLazyLoading`, `strict_loading`)
   — points to `file:line`.
2. **Test query-count assertion** — becomes a CI guardrail.
3. **Pattern detector** (`bullet`, `prosopite`, `nplusone`) — good in dev.
4. **Static / Semgrep** — catches new code in CI, without running.
5. **APM / tracing** (Datadog, Scout, OpenTelemetry span count) — catches what
   slipped through, in production.

## Common detection mistakes

- Measuring with `DEBUG`/logging off: counter stays zero, false "ok".
- Testing with 1 record: an N+1 with N=1 is 2 queries, looks fine. Use volume.
- "Curing" with eager load then `.filter()`/`.map()` on the relation in memory
  that re-runs the query — re-measure after the fix.
- Per-request cache implemented as a global cache: leaks data between users.

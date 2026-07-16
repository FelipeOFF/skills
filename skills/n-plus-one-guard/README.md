# n-plus-one-guard

Claude Code skill: detects and prevents **query N+1** (SQL/ORM) and redundant
HTTP/gRPC/service calls within a single request — and installs a
**per-endpoint query budget** that fails CI when the problem comes back.

**Language-agnostic** at its core, with sharp playbooks for the most common
stacks. The focus goes beyond "find today's N+1": it's **tool-based detection**
(lint, runtime guard, profiler) plus locking in a test guardrail against
regression.

## Structure (hub-and-spoke)

The hub (`SKILL.md`) is generic: mental model, the 3 detector classes, the
invariance test, budget allowlist, and per-stack routing. The spokes in
`references/` carry verified per-ecosystem syntax — the LLM loads the hub and
only the spoke for the detected stack.

**Core (always relevant):**

- `references/detection-playbook.md` — language-agnostic tool-first method
  (identify stack → static candidates → confirm at runtime → guardrail → CI).
- `references/false-cures-and-gotchas.md` — false cures and universal pitfalls.

**Per-language/stack spokes:**

| Stack | Reference |
|---|---|
| Python (Django + SQLAlchemy) | `references/python.md` |
| Node / TypeScript (Prisma, TypeORM, Sequelize, Drizzle, Knex) | `references/node-typescript.md` |
| Ruby on Rails (ActiveRecord) | `references/ruby-rails.md` |
| Java / Spring (Hibernate/JPA) | `references/java-spring.md` |
| Go (GORM, ent, sqlc) | `references/go.md` |
| PHP (Laravel Eloquent, Doctrine) | `references/php.md` |
| .NET (EF Core) | `references/dotnet.md` |
| Elixir (Ecto) | `references/elixir-ecto.md` |
| Rust (Diesel, SeaORM) | `references/rust.md` |
| Dart / Flutter (Drift, Isar, ObjectBox, Serverpod) | `references/dart.md` |
| MongoDB / ODMs (Mongoose, Beanie) | `references/mongo-odm.md` |
| GraphQL (DataLoader, cross-language) | `references/graphql-dataloader.md` |
| Static detection (Semgrep/ast-grep/lint) | `references/static-analysis.md` |
| HTTP / gRPC / microservice N+1 | `references/service-fanout.md` |

## What the skill delivers

- **Detect:** fail-at-point runtime guards (`raiseload`, `strict_loading`,
  `preventLazyLoading`), static analysis (Semgrep/ast-grep, `no-await-in-loop`),
  profilers/APM, and span-count via OpenTelemetry.
- **Measure:** per-request query interceptor/counter.
- **Lock:** per-endpoint query budget assertion (CI guardrail), with an
  invariance test (constant count vs. payload size).
- **Allowlist:** legitimate budgets, versioned and justified.
- **Fix:** eager loading, prefetch, DataLoader, batch endpoint, per-request cache.

## Install

```bash
npx skills add git@github.com:FelipeOFF/n-plus-one-guard-skill.git -y
```

Or via the [myskills](https://github.com/FelipeOFF/my-claude-code-skills)
marketplace (`programming@myskills`), where the skill ships pre-vendored.

## License

MIT © 2026 Felipe Oliveira

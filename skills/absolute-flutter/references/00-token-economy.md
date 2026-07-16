# 00 — Token economy: operating this skill cheaply

This is the FIRST reference to read. It is the operating manual for using
absolute-flutter without burning context. The skill is deliberately split into a
thin router (`SKILL.md`) plus twelve self-contained references and a folder of
copy-paste templates, precisely so you never have to load the whole architecture
to do one task. Follow these rules; each one explains WHY it saves tokens.

## Rules

### 1. Read the single relevant reference — not all twelve

Use the concern index in `SKILL.md` to pick the ONE reference for the task, then
stop. Adding a use case? Read `04-usecases.md` only. A route? `11-navigation.md`
only. The references are written self-contained for exactly this reason.

**Why:** each reference is ~250–400 lines. Reading one costs a few thousand
tokens; reading all twelve costs tens of thousands and fills context with detail
irrelevant to the task — which also degrades focus, not just budget. The router
exists so you can route, not read everything.

### 2. Copy a template, then rename anchors — don't regenerate

`assets/templates/` holds compile-shaped Dart skeletons keyed on neutral rename
anchors (`Feature`, `Example`, `Item`, `package:app/...`). To produce a file,
copy the matching template and rename the anchor to the real name — do not write
the file from scratch.

**Why:** regenerating a 60-line Dart file from prose re-derives boilerplate the
template already encodes correctly (imports, base-class wiring, `Either` folding,
`RxNotifier` getter/setter idiom). A rename is a handful of edits; regeneration
is hundreds of tokens of output plus the risk of drifting from the architecture
(wrong base class, relative imports, missing error funnel).

### 3. Batch file creation

When a task produces several files (a feature slice = page + controller + state
+ usecase + repository + binding + route), create them in one batched pass
rather than read-think-write-read-think-write per file.

**Why:** each round-trip carries fixed overhead (re-stating context, re-reading
the reference). Batching amortizes that overhead across all the files and keeps
the working set in one coherent mental pass instead of reloading it repeatedly.

### 4. Do not re-read files you just wrote

After you Write or Edit a file, its content is already known — the tooling
errors if the write failed, so a confirmation read tells you nothing new. Trust
the write and move on.

**Why:** a verification read of a file you authored this turn is pure waste — it
re-ingests content already in context. Reserve reads for files you have NOT
seen.

### 5. Use grep/glob to locate, not full reads to browse

In the user's existing project, find symbols with grep/glob (e.g. find the
`domain_binding.dart`, locate where `AppRouter` enum is declared, grep for an
existing `I*Repository`). Read only the specific span you need to edit.

**Why:** a glob returns paths for ~free; a targeted grep returns the few lines
that matter. Reading an entire `app_di.dart` or a 500-line `endpoints.dart` to
find one insertion point loads hundreds of irrelevant lines. Locate precisely,
then read narrowly.

### 6. Pull a second reference only when the task truly spans concerns

A full vertical feature legitimately spans mvvm + usecases + repository (+ di +
navigation). In that case, read those references — but only those, and only when
you reach that part of the work. A single-concern task (one route, one DTO
mapper, one interceptor) needs exactly one reference.

**Why:** speculative reading "to be safe" is the main way context fills up.
References are self-contained, so you can defer the second read until the task
actually crosses the boundary — and often it never does.

## Quick decision table

| Task | Read | Templates to copy |
|---|---|---|
| New app from zero | `01-architecture.md` (+ `02`, `03`) | folder scaffold, DI bootstrap, `main.dart` |
| One feature slice | `08-mvvm-rxnotifier.md` (+ `04`, `05`) | controller, page, binding, navigation quartet |
| One use case | `04-usecases.md` | abstract base + concrete use-case shapes |
| One repository | `05-repository.md` | interface+impl pair, DTO mapper |
| Backend/dio layer | `06-gateway-backend.md` | gateway, client, interceptor, endpoints |
| Cache | `07-cache-database.md` | drift table, `FuCache` decorator |
| DI wiring | `03-di.md` | `AbstractBinding`, `AppDI` |
| A route | `11-navigation.md` | `AppRouter` enum, `BaseNavigation` |
| Push / deep links | `12-push-deeplink.md` | push facade, deep-link cubit |
| Theming | `09-design-system.md` | `ThemeExtension` palette, context ext |
| Extensions | `10-extensions.md` | per-type util extensions |
| Map an existing project | `01-architecture.md` | — (read + grep, don't write) |

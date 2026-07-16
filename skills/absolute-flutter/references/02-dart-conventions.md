# 02 — Dart conventions: imports, style, and codegen

The mechanical contract every Dart file in this skill obeys: how imports are
written and ordered, the lint/format rules, and the `build_runner` codegen
toolchain that turns thin annotated sources into `*.freezed.dart` / `*.g.dart`
siblings. Read this when setting up a new app's config files, when writing a DTO,
or when a lint/build error is fighting you.

## When to use

Read this reference when you are:

- Scaffolding a new app and need `analysis_options.yaml`, `build.yaml`, and the
  codegen slice of `pubspec.yaml`.
- Writing or renaming a data class (freezed + `json_serializable` DTO) or a
  custom `JsonConverter`.
- Hitting a lint that won't quiet, an import-ordering complaint, or a build that
  emits `Instance of '...'` / mismatched drift output.
- Deciding where a generated sibling goes, or whether a file should be analyzed.

You do NOT need this for a route, a use case, or a controller — those have their
own references. This is purely style + codegen plumbing.

## Pattern (the why)

**Pinned, explicit lints — no shared ruleset.** `analysis_options.yaml`
enumerates every rule one-by-one instead of `include:`-ing `flutter_lints` or
`very_good_analysis`. WHY: the project pins exact lint behavior and is immune to
upstream churn — a package bump can never silently relax or tighten a rule. The
cost (a long list) buys total determinism.

**`package:` imports always; relative imports are a lint error.** Every import is
`package:app/...` (or a third-party `package:...`). `always_use_package_imports`
+ `avoid_relative_lib_imports` make `../foo.dart` fail analysis. WHY: stable,
refactor-safe paths and exactly one canonical way to reference any symbol —
moving a file never rewrites a web of relative paths.

**One sorted import block.** `directives_ordering` sorts ALL imports
alphabetically in a single block — Dart SDK, Flutter, third-party, and your own
`package:app/...` together, no blank-line groups, no `// Flutter` / `// Package`
comment headers. `part` directives come AFTER all imports, before the first
declaration. WHY: the formatter and lint own ordering so humans never argue about
it; adding manual groups just makes the lint fight you.

**Single source of truth via codegen.** You hand-write a thin annotated `*.dart`;
`build_runner` emits the boilerplate as `part` siblings. Immutable data classes =
`@freezed` + `json_serializable`. DB = `drift` (modular codegen). i18n =
`intl_utils` from `.arb`. Generated files are committed to git but never edited
and excluded from the analyzer. WHY: the wire shape, `copyWith`, `==`, JSON
mapping, and SQL are derived from one declaration — they cannot drift out of sync
with the source the way duplicated hand-written code does.

**Frozen classes stay pure data.** Behavior — derived getters, cross-DTO mappers
— goes in `extension XOnY`, never as methods on the `@freezed` class. WHY: methods
on a frozen class collide with the generated mixin and trip the freezed
private-constructor error; the extension keeps the generated code clean.

**120-column formatting** via the modern `formatter: { page_width: 120 }` block
(Dart 3.7+ formatter), not the legacy `dart_style` key. Single quotes, aggressive
`const` and `final`, always-declared return types, expression (`=>`) bodies for
one-liners. WHY: a wider line fits the deeply-nested constructor calls this
architecture produces without gratuitous wrapping.

## Folder placement

```
lib/
  analysis_options.yaml   # actually at app ROOT, next to pubspec.yaml
  build.yaml              # app ROOT
  pubspec.yaml            # app ROOT — merge pubspec.partial.yaml into this
  model/
    api/
      example_dto.dart            # @freezed DTO source
      example_dto.freezed.dart    # generated sibling (committed, not analyzed)
      example_dto.g.dart          # generated sibling (committed, not analyzed)
      common/                     # shared API DTOs (ProfileDto, etc.)
  common/helper/
    timestamp_serializer.dart     # custom JsonConverter(s)
  generated/
    l10n.dart                     # intl_utils output (analyzer-excluded)
  res/l10n/
    intl_en.arb                   # .arb source files
```

- `analysis_options.yaml`, `build.yaml`, and `pubspec.yaml` live at the **app
  root**, not in `lib/`.
- Codegen siblings live **next to** their source: `example_dto.dart` →
  `example_dto.freezed.dart` + `example_dto.g.dart`. Never in a separate
  `generated/` folder (except `intl_utils`, which does output to
  `lib/generated/`).
- File names are always `snake_case.dart`.

## Templates

Copy these from `assets/templates/config/` and merge / rename as noted. Prefer
copying over regenerating.

| File | What it is |
|---|---|
| `assets/templates/config/analysis_options.yaml` | The explicit lint allowlist + `strict-casts` + `formatter.page_width: 120` + analyzer `exclude:` for `*.g.dart` / `*.freezed.dart` / `*.drift.dart` / `lib/generated/**`. Copy verbatim; no renaming. |
| `assets/templates/config/build.yaml` | Per-builder codegen options: `freezed { format: true }`, `json_serializable { explicit_to_json, any_map }`, `drift_dev` off / `drift_dev:analyzer` + `drift_dev:modular` on via a shared `&options` anchor, `intl_utils`. Copy verbatim. |
| `assets/templates/config/pubspec.partial.yaml` | The codegen SLICE of `pubspec.yaml` — runtime deps, the `build_runner` / `freezed` / `json_serializable` / `drift_dev` / `intl_utils` dev_dependencies, the `intl: any` override, `flutter: { generate: true }`, and the `flutter_intl:` block. MERGE into the real pubspec; do not ship as-is. |
| `assets/templates/config/example_dto.dart` | A `@freezed` + `json_serializable` DTO with an enum (`@JsonValue`), a custom-converter field, a named convenience factory, `fromJson` last, and an `extension` for derived getters. Rename `Example` to your entity. |
| `assets/templates/config/json_converter.dart` | A custom `JsonConverter` (`TimestampSerializer`, String ↔ DateTime) for `lib/common/helper/`. Rename and swap the type arguments for your conversion. |

## Step-by-step to apply

**Setting up codegen in a new app:**

1. Copy `analysis_options.yaml` and `build.yaml` to the app root verbatim.
2. Merge the blocks from `pubspec.partial.yaml` into the real `pubspec.yaml`
   (deps, dev_dependencies, `dependency_overrides`, `flutter: generate: true`,
   `flutter_intl:`). Keep the existing `name: app`, `version`, etc.
3. `flutter pub get`.
4. `dart run build_runner build --delete-conflicting-outputs` to emit the first
   siblings; `dart run intl_utils:generate` for `lib/generated/l10n.dart`.

**Adding a DTO:**

1. Copy `example_dto.dart` to `lib/model/api/<name>_dto.dart`.
2. Rename `Example`/`ExampleDto`/`ExampleType` to your entity; fix the two `part`
   lines to match the new file name; adjust fields.
3. If a field needs custom (de)serialization, copy `json_converter.dart` into
   `lib/common/helper/`, rename it, and annotate the field with it.
4. `dart run build_runner build --delete-conflicting-outputs`. Commit the
   `*.freezed.dart` + `*.g.dart` siblings; never hand-edit them.

## Gotchas

- **Generated siblings are committed but never hand-edited.** They carry
  `// GENERATED CODE - DO NOT MODIFY BY HAND` and `// ignore_for_file: type=lint`.
  Change the source and rerun `build_runner`, never the `.g.dart`/`.freezed.dart`.
- **`directives_ordering` is one alphabetical block.** Do not add blank-line
  groups or `// Flutter` / `// Package` comment headers — the lint will rewrite
  them away and complain. SDK, third-party, and `package:app/...` all sort
  together.
- **`explicit_to_json: true` is required** for nested freezed DTOs. Omit it and
  serialization silently emits `Instance of '...'` for nested objects instead of
  a map.
- **`any_map: true` changes the `fromJson` signature.** Generated decoders accept
  untyped `Map`, not `Map<String, dynamic>` — so the template's factory is
  `factory ExampleDto.fromJson(Map json)`, matching the generated `_$...FromJson`.
- **Drift is modular-only.** Non-modular `drift_dev` is disabled; only
  `drift_dev:analyzer` + `drift_dev:modular` run, emitting one `*.drift.dart` per
  table. Code expecting monolithic drift output will break the build.
- **`store_date_time_values_as_text: true`** stores ISO-8601 text, not unix ints.
  Flipping it is a breaking schema migration.
- **`strict-casts: true` rejects implicit downcasts.** You need explicit `as` (or
  null-aware helpers) even in glue code — including inside `JsonConverter.fromJson`,
  which is why the template casts `timestamp as String?` before parsing.
- **SDK `^3.9.0` is load-bearing.** The null-aware map-literal element syntax
  (`{'k': ?maybeNull}`) used in request bodies needs it; an older SDK won't parse.
- **`intl: any` in `dependency_overrides`** pins around a transitive conflict. Do
  not bump `intl` directly without checking `intl_utils` compatibility first.
- **Frozen class with a method?** Move it to an `extension`. A non-factory method
  on a `@freezed` class collides with the generated mixin and fails to compile.

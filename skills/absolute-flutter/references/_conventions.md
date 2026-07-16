# Shared contract — sanitization, naming, and canonical patterns

This is the SINGLE SOURCE every reference doc and every template in this skill
obeys. Read it before emitting any Dart. If a template and this file ever
disagree, this file wins.

## Package name and imports

- The generated app's package name is **`app`**. Every import is
  `package:app/...`. **ALWAYS package imports, NEVER relative imports** (`../`
  is forbidden, even within the same feature folder).
- Third-party imports use their own package path as usual
  (`package:rx_notifier/rx_notifier.dart`, `package:dartz/dartz.dart`,
  `package:dio/dio.dart`).

## Neutral domain only

- Use ONLY these example nouns as domain stand-ins: **Example, Item, Auth, User,
  Profile, Feature, Home, Detail, Settings**.
- **FORBIDDEN** in any doc, template, identifier, comment, or path: any real
  brand or app name, any third-party company or product name, and any
  business-domain noun lifted from a specific real product. If a noun describes
  what some particular app sells, mints, trades, or pays out, it does not belong
  here — keep every example in the neutral vocabulary above.
- If a real host or URL would appear, replace it with `https://api.example.com`.

## Canonical state management — rx_notifier MVVM

- The canonical state-management stack is **rx_notifier**. The ViewModel is a
  **`Controller`** that extends **`BaseController`** and exposes its mutable UI
  state as **`RxNotifier`** fields (private notifier + public getter/setter).
- The View is a `StatefulWidget` whose `State` extends
  `BaseState<Widget, Controller>`. It reads controller state **only inside
  `RxBuilder`**, which re-runs automatically when any touched `RxNotifier`
  changes. There is no separate `State` data class — reactive fields live on the
  controller.
- Present rx_notifier as THE pattern everywhere. **`flutter_bloc` / Cubit is a
  one-line legacy aside only** — never the carrier of new logic, never the
  example to reach for.

## Use-case execution ladder

- The execution ladder (loading toggle + `Either` fold + error routing +
  auto-logout) lives in a **`BaseController` mixin**, rx_notifier variant:
  **`execSingle`** (run one use case, fold its `Either`) and **`execCallback`**
  (run a callback that returns `Either`). The Controller calls these; it never
  unwraps `Either` by hand.
- Do NOT make a Cubit the carrier of this ladder. The ladder is a `BaseController`
  concern in this skill.

## Error model

- Errors are a sealed **`AppError`** with variants **`Default`**, **`Logout`**,
  **`NetworkException`**, **`UnknownException`**.
- Results crossing the domain boundary are **`Either<AppError, T>`** via
  **dartz**.
- Transport errors are mapped by **`DioException.asAppError()`**: 401 →
  `Logout`, offline → `NetworkException`, parsed body → `Default`, otherwise →
  `UnknownException`.
- The use case's `call()` is the **single** try/catch + `Either` boundary. The
  UI never sees a raw exception.

## Dart style

- Single quotes for strings.
- Prefer `const` wherever possible (constructors, literals).
- Always declare return types.
- File names: `snake_case`. Types: `PascalCase`. Members: `camelCase`.
- 120-column line width (`formatter.page_width: 120`).

## Templates as rename anchors

- Templates are **valid, compile-shaped Dart skeletons** (balanced braces, real
  `package:app/...` imports) that use the neutral nouns above as rename anchors —
  e.g. `class FeatureController`, `class ExampleDto`, `class IItemRepository`.
- A generator (or you, by hand) renames the anchor (`Feature`, `Example`,
  `Item`) to the real feature/entity name. Keep every template balanced and
  importable so the renamed result compiles.

## Token economy

- `SKILL.md` stays a thin router. Heavy detail lives in `references/`, loaded on
  demand.
- Each reference is self-contained. If a reference exceeds ~300 lines, add a
  table of contents at the top.
- Prefer pointing at a template file in `assets/templates/` over inlining a full
  file in prose. See `00-token-economy.md` for the full operating rules.

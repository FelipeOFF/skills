# 10 — Extensions: Kotlin-style extension functions as the glue layer

Dart `extension` declarations are the primary mechanism in this codebase for
adding behavior to types you don't own — native types (`String`, `num`,
`Iterable`, `Object`), `BuildContext`, enums, and transport DTOs. They replace
free helper functions and `XxxUtils` static classes. Call sites read fluently:
`value.capitalize`, `context.colors.primary`, `itemType.label`,
`dto.toItemView()`, `result.unwrapRight`.

Read `_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Add a pure helper on a native type (validation, formatting, null-safe access,
  casting) instead of a `Utils` class or a top-level function.
- Add theme/DI/navigation/MediaQuery glue reachable from a widget as
  `context.<thing>`.
- Map an enum to a localized label or an icon token without putting presentation
  on the enum or in the widget.
- Map a transport DTO to a view/domain shape (`dto.toXView()`).
- Unwrap or chain a dartz `Either` ergonomically.

If you are deciding *whether* a helper should be an extension at all, the rule is
in `02-dart-conventions.md` ("Frozen class with a method? Move it to an
extension"). This doc is about the extension *families* and where each lives.

## Pattern (the why)

Five extension families, each with a distinct job and a distinct home:

1. **Native-type utility extensions** — on `String`, `num`, `Iterable<T>`,
   `Object`/`dynamic`. Pure helpers: validation, formatting, null-safe access,
   casting, `let`. One type per file under `common/util/`.
2. **`BuildContext` capability extensions** — design-token access
   (`context.colors`), DI singletons (`context.analytics`), typed navigation,
   MediaQuery sizing, snackbars. Split by concern across files to limit import
   fan-out.
3. **`Either` helpers** — generic `on Either<L, R>` (dartz): `unwrapRight`,
   `getOrElse`, `onRight`/`onLeft`. The SAME file the controller ladder imports.
4. **Enum extensions** — `get label` / `get icon` via exhaustive Dart 3 `switch`
   expressions. Keeps presentation off the enum.
5. **Model/DTO extensions** — `toXView()` mappers + derived getters, co-located
   with the feature's model.

Why this is the house style:

- **Fluent, discoverable call sites.** `context.colors.primary`,
  `count.formatCompact(locale)`, `dto.toItemView()` beat
  `ColorUtils.primary(context)` or `Mapper.map(dto)`. The receiver leads, so
  autocomplete surfaces the helper where you'd look for it.
- **Native types stay native.** No wrapper classes, no subclassing — behavior is
  added in place.
- **Generics over duplication.** `let`, `castOrNull`, `safeGet`, `sumBy`,
  `unwrapRight` are written ONCE on the most general receiver (`T`,
  `Iterable<T>`, `Either<L, R>`) and reused everywhere.
- **Single source for design tokens.** All theme access funnels through one
  `BuildContext` extension (`context.colors`), so a token rename is one edit and
  widgets never call `Theme.of` for tokens directly.
- **Presentation off the model.** Enum→label/icon mapping lives in an extension
  with an exhaustive `switch` and NO `default`, so adding an enum case breaks
  compilation in every mapping until it's handled. The compiler is the safety
  net.
- **`get` for purity, method for parameters.** No-arg, side-effect-free →
  getter (`isBlankOrNull`, `capitalize`, `label`, `unwrapRight`). Needs an
  argument / `BuildContext` / `Locale` → method (`format(locale)`,
  `pushToDetail(id)`, `ellipsize(maxLength)`). Call sites then read like
  properties whenever there's no computation context.

## Folder placement

```
lib/
  common/util/                       # native-type + Either + context helpers
    string_ext.dart                  #   extension StringExt on String
    num_ext.dart                     #   extension FormatterX on num (+ free helper)
    list_ext.dart                    #   extension ListExt<T> on Iterable<T>
    object_ext.dart                  #   ObjectExt<T> on T (let) + CastOrNull x2
    either_helpers.dart              #   EitherHelpers<L,R> on Either<L,R>
    context_capability_ext.dart      #   BuildContext: design/DI/nav/MediaQuery
  model/extensions/
    item_type_extensions.dart        #   ItemTypeX on ItemType (label/icon switch)
  feature/<feature>/model/
    item_dto_extensions.dart         #   ItemDtoExtensions on ItemDto (toXView)
```

Placement rules:

- **Native-type helpers → `common/util/<type>_ext.dart`, one type per file.**
  Findable by type name; avoids merge churn.
- **`Either` helpers → `common/util/either_helpers.dart`** — this is the SAME
  file `BaseController` imports (`execSingle` reads an `Either` exactly this
  way). There is ONE per app; do not fork a second copy.
- **`BuildContext` glue → `common/util/context_*_ext.dart`.** Token access and
  capability helpers are SPLITTABLE: a single file that imports routers + DI +
  design system + l10n couples everything. The template ships them in one file
  but as three separate extensions — split into files as it grows.
- **Enum presentation → `model/extensions/<enum>_extensions.dart`.**
- **DTO mappers → co-located with the DTO model** or under the feature's
  `model/`.

## Templates

Copy from `assets/templates/extensions/` and rename the anchors (`Item`,
`Example`, `Feature`, `ItemType`) to the real type. Each file's header comment
states its target path and the rule it demonstrates.

| File | What it is |
|---|---|
| [`string_ext.dart`](../assets/templates/extensions/string_ext.dart) | `StringExt on String` — validation, `capitalize`, `ellipsize(int)`, a named boolean rule-set map. Getter-vs-method split demonstrated. |
| [`list_ext.dart`](../assets/templates/extensions/list_ext.dart) | `ListExt<T> on Iterable<T>` — `safeElementAt` / `safeGet` (return `T?`, never throw), `firstWhereOrNull`, selector-based `sumBy`. |
| [`object_ext.dart`](../assets/templates/extensions/object_ext.dart) | `ObjectExt<T> on T` (`let`) + `castOrNull<T>()` declared TWICE (on `Object` and `dynamic`) — the load-bearing duplication. |
| [`either_helpers.dart`](../assets/templates/extensions/either_helpers.dart) | `EitherHelpers<L,R> on Either<L,R>` (dartz) — `unwrapRight`/`unwrapLeft`, `getOrElse`, `onRight`/`onLeft`. The controller-ladder file. |
| [`num_ext.dart`](../assets/templates/extensions/num_ext.dart) | `FormatterX on num` — locale-aware `format` / `formatFixed` / `formatCompact` (12k/3.4M/1B) + a free module-level `currencySymbolFor`. |
| [`context_capability_ext.dart`](../assets/templates/extensions/context_capability_ext.dart) | Three `BuildContext` extensions: design tokens (`context.colors`), DI (`context.analytics`), nav/snackbar/MediaQuery (`pushToDetail`, `squareTileSize`). |
| [`enum_label_ext.dart`](../assets/templates/extensions/enum_label_ext.dart) | `ItemTypeX on ItemType` — `get label` / `get icon` via exhaustive `switch` with NO default; `S.current` for context-free i18n. |
| [`dto_mapper_ext.dart`](../assets/templates/extensions/dto_mapper_ext.dart) | `ItemDtoExtensions on ItemDto` — `toItemView()` mapper, nullable wire fields guarded, derived value computed safely. |

`either_helpers.dart` is shared infrastructure — copy it ONCE per app, not per
feature. (It is also referenced by the use-case layer; see `04-usecases.md`.)

## Step-by-step to apply

1. **Pick the family and the home.** Native-type helper →
   `common/util/<type>_ext.dart`. Context glue → `common/util/context_*_ext.dart`.
   Enum presentation → `model/extensions/`. DTO mapper → next to the DTO.
2. **Copy the matching template** and rename the anchor type (`Item`,
   `ItemType`, `Example`) to the real type throughout — class name, file name,
   method names.
3. **Choose getter vs method.** No args and no side effects → `get`. Takes an
   argument / `BuildContext` / `Locale`, or computes a format → method. Declare
   the return type always (style rule).
4. **Keep `this` correct.** Member access is implicit (`trim()`,
   `substring(...)`). `this` is EXPLICIT in interpolation and arithmetic
   (`'$this'`, `this / 1000`) and when passing the receiver as an argument.
5. **For enums, write an exhaustive `switch` with NO `default`.** One expression
   body per getter, one arm per case. Use `S.current` for labels (no context in
   a getter). Map icons to the `AppIcons` token registry.
6. **For DTO mappers, treat every wire field as nullable.** Guard before any
   division or parse (`count != null && count! > 0 ? total! / count! : null`);
   never force-unwrap untrusted transport data.
7. **Import the extension file at every call site.** Dart extensions are not
   auto-visible — the file that uses `value.capitalize` must
   `import 'package:app/common/util/string_ext.dart';`. One-type-per-file makes
   the import predictable.
8. **Prefer reusing the generic helper** over writing a near-duplicate. If you
   need a new `safe*`/`unwrap*`/`let`-like helper, add it to the existing
   generic extension rather than a type-specific copy.

## Gotchas

- **Import the extension or it won't resolve.** Extensions are not auto-imported.
  A missing import shows up as "the getter/method isn't defined for the type" —
  add the `package:app/...` import for the declaring file.
- **`castOrNull` must be declared on both `Object` AND `dynamic`.** An
  `on Object` extension does not match a receiver statically typed `dynamic`.
  `object_ext.dart` declares both; delete one and `someDynamic.castOrNull<T>()`
  stops resolving. This is intentional duplication.
- **Extension method resolution is STATIC** (by the variable's declared type, not
  its runtime type). `safeGet`/`castOrNull` on a `dynamic`-typed variable only
  see the `dynamic` extension; on a `List`-typed variable, the `Iterable`
  extension.
- **No `default` in enum `switch` expressions — on purpose.** Adding an enum
  value SHOULD break compilation in every mapping extension so you're forced to
  handle it. A catch-all `_ =>` hides that and defeats the pattern.
- **`S.current` vs `S.of(context)`.** Context-free extensions (enum label
  getters) use the static `S.current`; context-bearing methods use
  `S.of(context)`. Mixing them wrong yields a stale or null locale.
- **`unwrapRight` returns `R?` — null is ambiguous.** A legitimately-null `Right`
  is indistinguishable from a `Left`. When `R` is nullable, check `isLeft()`
  first (or use `getOrElse`). The controller ladder does this; preserve the order
  when unwrapping by hand.
- **`this` in interpolation/arithmetic must be explicit.** `'$this'`,
  `this / 1000`, `this.abs()` — forgetting `this` is the classic slip in
  number/format extensions and is a silent bug, not always a compile error.
- **Don't let one `BuildContext` file import everything.** A nav extension that
  pulls in routers, dialogs, DI, l10n, and models creates wide fan-out. Keep
  token access, DI access, and navigation in separate extensions/files (the
  template already splits them) so a widget that only needs `context.colors`
  doesn't transitively drag in the router graph.
- **Not everything is an extension.** When there's no natural receiver (e.g. a
  currency symbol from a code), a free module-level function is correct —
  `num_ext.dart` keeps `currencySymbolFor` as a plain function beside the
  extension. Don't contort a helper onto a receiver it doesn't belong on.
</content>
</invoke>

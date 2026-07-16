# 09 — Design system: ThemeExtension tokens via one BuildContext extension

The presentation foundation. Design tokens — color, typography, icon tint,
decoration, spacing — are `ThemeExtension<T>` subclasses registered on
`ThemeData`, and every widget reaches them through ONE `extension on
BuildContext`. A widget writes `context.colors.primary`, `context.text.bodyMedium`,
`context.s.md` — never a raw `Color(0x...)` literal and never `Theme.of(context)`
directly. Raw hex lives in exactly one class.

Read `_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Stand up the design system in a new app (token classes + `ThemeData` wiring).
- Add a new token (a color, a text style, a decoration, a spacing step) or a
  whole new token group.
- Add an icon, or build a reusable component that must consume tokens.
- Fix a widget that hardcodes a `Color`, calls `Theme.of(context)` directly, or
  reads `AppColor` — migrate it onto `context.*`.

It is upstream of every feature View (`07-*`/`08-*` controller+view work): those
widgets style themselves through the `context.*` surface defined here.

## Pattern (the why)

- **Tokens are `ThemeExtension<T>` subclasses, not a static-constants class.**
  WHY: a ThemeExtension animates across theme transitions (`lerp`), swaps per
  brightness/brand, and binds to the widget tree via
  `Theme.of(context).extension<T>()` so a nested `Theme` override actually takes
  effect. A `static const` class gives none of that.
- **One token group per class, each carrying the same quartet.** Every group
  (`AppColorsTheme`, `AppTextTheme`, `AppIconsTheme`, `AppDecorationTheme`,
  `AppSpacingTheme`) declares its fields, a private `._` const constructor, a
  static `of` / `maybeOf` accessor pair, and the two mandatory overrides
  `copyWith` + `lerp`. Each field is threaded through FOUR places (decl, ctor,
  copyWith, lerp). It is boilerplate-heavy on purpose — that is the cost of
  type-safe, animatable tokens.
- **All tokens reach widgets through ONE `extension on BuildContext`.** WHY: it
  removes `Theme.of(context).extension<AppColorsTheme>()!` boilerplate at every
  call site. `context.colors.primary` is short, greppable, and refactor-safe.
  This is the ENFORCED access path — widgets do not call `of(context)` directly
  and never touch `AppColor`.
- **Raw hex lives in exactly ONE class (`AppColor`).** Private `_()` constructor,
  `@protected` const fields. Palettes map SEMANTIC names onto `AppColor.*`;
  widgets never read it. WHY: a hex change ripples through tokens, never through
  call sites — `AppColor` is the single source of truth and the refactor
  choke-point.
- **Tokens are registered ONCE in `ThemeData.extensions: [...]`.** Access is
  theme-driven, so it survives theme swaps and animates via `lerp`. The `of()`
  accessor uses `!` — an extension you forgot to register throws at the first
  call site, not at startup.
- **Atoms = enum asset registry + a thin renderer.** Icons are an `enum AppIcons`
  (asset path + a11y label per value) plus an `AppIcon` widget that paints one,
  defaulting size and tint from the ambient `IconTheme`. WHY: asset paths and
  labels are compile-checked — a typo is a compile error, not a missing asset.
- **Components consume tokens, never raw values.** A reusable widget styles
  itself entirely from `context.*`; an optional param overrides a token default
  (`backgroundColor ?? context.colors.surface`). No `Color(0x...)`, no
  `Theme.of`, no `AppColor` anywhere in a component body.

## Folder placement

```
lib/
  design_system/
    theme/
      app_color.dart                 # ONLY place raw hex lives (AppColor, private ctor)
      app_colors_theme.dart          # AppColorsTheme ThemeExtension (the palette pattern)
      app_theme.dart                 # text/icons/decoration/spacing groups + ThemeData wiring
      app_context_extensions.dart    # extension on BuildContext (context.colors/text/icons/...)
    atoms/
      app_icons.dart                 # enum AppIcons (asset path + a11y label)
      app_icon.dart                  # AppIcon renderer (SvgPicture, IconTheme defaults)
    components/
      example_component.dart         # reusable widget consuming tokens via context.*
```

`MaterialApp` is handed the assembled theme: `theme: appDarkTheme` (see
`app_theme.dart`). Each token group keeps its accessor + overrides in its own
class file; the smaller groups (text/icons/decoration/spacing) ride along in
`app_theme.dart` next to the `ThemeData` that registers them.

## Templates

Copy from `assets/templates/design_system/` and rename the anchors (`App`,
`Example`) to your real names. The token-group quartet (fields → `._` ctor →
`copyWith` → `lerp`) must stay intact when you add or remove a field.

| File | What it is |
|---|---|
| [`app_color.dart`](../assets/templates/design_system/app_color.dart) | The ONE raw-hex registry: `AppColor` with private `_()` ctor and `@protected` const fields. Single source of truth; widgets never read it. |
| [`app_colors_theme.dart`](../assets/templates/design_system/app_colors_theme.dart) | `AppColorsTheme` — the palette pattern: a `ThemeExtension` with `of`/`maybeOf` + `copyWith` + `lerp`, fields mapping onto `AppColor.*`. Repeat this shape per token group. |
| [`app_theme.dart`](../assets/templates/design_system/app_theme.dart) | The remaining token groups (`AppTextTheme`, `AppIconsTheme`, `AppDecorationTheme`, `AppSpacingTheme`) + the `ThemeData` that registers EVERY extension. |
| [`app_context_extensions.dart`](../assets/templates/design_system/app_context_extensions.dart) | The single `extension on BuildContext`: `context.colors` / `text` / `icons` / `decoration` / `s`. The enforced token access path. |
| [`app_icons.dart`](../assets/templates/design_system/app_icons.dart) | `enum AppIcons` — asset path + a11y label per glyph. Compile-checked atom registry. |
| [`app_icon.dart`](../assets/templates/design_system/app_icon.dart) | `AppIcon` renderer: paints an `AppIcons` value, defaulting size/tint from `IconTheme`. |
| [`example_component.dart`](../assets/templates/design_system/example_component.dart) | A reusable component consuming tokens via `context.*` only — no raw `Color`, no `Theme.of`, no `AppColor`. The everyday widget shape. |

`app_color.dart`, `app_theme.dart`, `app_context_extensions.dart`, and the two
atom files are app-wide infrastructure — copy them ONCE per app. Add new token
groups beside `AppColorsTheme`; add new components beside `example_component.dart`.

## Step-by-step to apply

1. **Seed the raw palette.** In `app_color.dart`, add the brand/neutral/feedback
   hex literals to `AppColor` (`@protected static const`). Use a `MaterialColor`
   swatch for any color that needs `.shade100..700`. This is the ONLY file with
   `Color(0x...)` literals.
2. **Define each token group.** For colors, copy `app_colors_theme.dart`; map
   its semantic fields onto `AppColor.*`. For other groups, follow the same
   quartet in `app_theme.dart`. Every field must appear in the field decl, the
   `._` ctor, `copyWith`, AND `lerp` — thread it through all four or `lerp`
   silently drops it.
3. **Assemble the `ThemeData`.** In `app_theme.dart`, list EVERY token group in
   `extensions: <ThemeExtension<dynamic>>[...]`. A group missing from this list
   makes its `context.*` getter throw at runtime via the `!` in `of()`.
4. **Expose the context surface.** In `app_context_extensions.dart`, add one thin
   getter per group: `AppColorsTheme get colors => AppColorsTheme.of(this);`. This
   is what widgets import and call.
5. **Wire it into the app.** Pass `theme: appDarkTheme` to `MaterialApp` (see
   `app_scaffold`). Tokens now resolve anywhere below it.
6. **Register icons.** Add glyphs to `enum AppIcons` (asset path + label) and
   declare the assets in `pubspec.yaml`. Render with `AppIcon(AppIcons.x)`.
7. **Build components against tokens.** Style every widget from `context.*`
   (`context.colors`, `context.text`, `context.s`, `context.icons`,
   `context.decoration`). Accept an optional override param that falls back to a
   token (`color ?? context.colors.primary`). NEVER a raw `Color`, `Theme.of`,
   or `AppColor` in a component.
8. **Migrate strays.** When you find a widget with a hardcoded `Color(0x...)` or
   a `Theme.of(context).colorScheme...`, replace it with the nearest token. If no
   token fits, add one (steps 1–4) rather than hardcoding.

## Gotchas

- **`of()` uses `!` — register or it throws.** Every token group MUST be listed
  in `ThemeData.extensions`. Forget one and the first `context.x` that reads it
  throws at runtime (not at startup). Adding a token group = update its class file
  AND the `extensions` list. Use `maybeOf` only where a missing extension is
  legitimately tolerable.
- **`copyWith` + `lerp` must cover every field.** A field present in the decl but
  missing from `lerp` is frozen during theme transitions; missing from `copyWith`
  it can't be overridden. When you add a field, thread it through all four sites.
- **`MaterialColor` (and other non-lerpable types) skip interpolation.** In
  `lerp`, pass swatch fields through unchanged (`t < 0.5 ? a : b`) — `MaterialColor`
  does not `Color.lerp` cleanly. Only plain `Color` / `TextStyle` / `double`
  fields interpolate.
- **Non-const decorations can't sit in a `const` extensions list.**
  `BoxDecoration` with `withValues(...)` / `BorderRadius.circular(...)` is not a
  const expression, so `AppDecorationTheme` is attached via `.copyWith(extensions:
  [...])` after the const groups rather than inlined — see `app_theme.dart`.
- **The context extension is a normal import, not part of the barrel.** It may
  pull in l10n or other libs, so a widget imports `app_context_extensions.dart`
  directly (plus the group's type if it names it). Don't try to re-export it
  through a `part`/`part of` barrel.
- **`AppColor` is `@protected` by convention.** Even inside the library, reach
  color through palettes/`context.colors`, never by reading `AppColor.*` into a
  widget. The `@protected` annotation is the lint nudge; the discipline is the
  point.
- **One theme today, multi-theme tomorrow.** The templates ship a dark theme. A
  light/alternate theme is a parallel set of `.light` instances + a second
  `ThemeData` with the SAME `extensions` shape — the architecture is already
  multi-theme-ready, nothing structural changes.
- **Icons: two systems can coexist.** The enum-SVG atom (`app_icons.dart`) is for
  asset SVGs. A generated icon-font (`IconData` glyphs) is a separate concern —
  don't conflate them; keep the SVG atom for design-system iconography.

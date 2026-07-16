// lib/design_system/theme/app_colors_theme.dart
//
// A token group expressed as a ThemeExtension<T> — NOT a static-constants class.
// WHY a ThemeExtension: it animates across theme transitions (`lerp`), swaps per
// brightness/brand, and binds to the widget tree via
// `Theme.of(context).extension<T>()` so nested theme overrides work.
//
// This is the PALETTE PATTERN — repeat it once per token group (colors here; an
// IconsPalette, a DecorationTheme, a TextTheme extension each follow the same
// shape). Every field is threaded through FOUR places: the field decl, the
// const `._` ctor, copyWith, and lerp. Rename `AppColorsTheme` and its fields to
// your real groups; keep the of/maybeOf + copyWith + lerp quartet intact.
import 'package:flutter/material.dart';
import 'package:app/design_system/theme/app_color.dart';

@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  const AppColorsTheme._({
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.neutral,
    required this.success,
    required this.danger,
  });

  // The concrete dark instance. Add a parallel `.light` to go multi-theme — the
  // ThemeData just registers whichever matches its brightness (see app_theme.dart).
  static const AppColorsTheme dark = AppColorsTheme._(
    primary: AppColor.primaryPure,
    primaryDark: AppColor.primaryDark,
    background: AppColor.background,
    surface: AppColor.surface,
    neutral: AppColor.neutral,
    success: AppColor.success,
    danger: AppColor.danger,
  );

  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color surface;
  // A MaterialColor swatch: `context.colors.neutral.shade600` resolves a shade.
  final MaterialColor neutral;
  final Color success;
  final Color danger;

  // The enforced access path: `AppColorsTheme.of(context)` (wrapped by
  // context.colors). `!` asserts the token is registered in ThemeData.extensions
  // — forget to register it and this throws at the first call site.
  static AppColorsTheme of(BuildContext context) => Theme.of(context).extension<AppColorsTheme>()!;

  // Null-safe variant for code that must tolerate a missing extension.
  static AppColorsTheme? maybeOf(BuildContext context) => Theme.of(context).extension<AppColorsTheme>();

  @override
  AppColorsTheme copyWith({
    Color? primary,
    Color? primaryDark,
    Color? background,
    Color? surface,
    MaterialColor? neutral,
    Color? success,
    Color? danger,
  }) {
    return AppColorsTheme._(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      neutral: neutral ?? this.neutral,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColorsTheme lerp(covariant ThemeExtension<AppColorsTheme>? other, double t) {
    if (other is! AppColorsTheme) return this;
    return AppColorsTheme._(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t) ?? primaryDark,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      // MaterialColor does not lerp cleanly — pass the swatch through unchanged.
      neutral: t < 0.5 ? neutral : other.neutral,
      success: Color.lerp(success, other.success, t) ?? success,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
    );
  }
}

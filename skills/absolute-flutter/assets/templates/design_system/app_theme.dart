// lib/design_system/theme/app_theme.dart
//
// Where the design system is ASSEMBLED. This file:
//   1. Declares the remaining token-group ThemeExtensions that back the context
//      getters (text / icons / decoration / spacing). Colors live in their own
//      file (app_colors_theme.dart); these smaller groups ride along here.
//   2. Wires a ThemeData and REGISTERS every extension in `extensions: [...]`.
//
// CRITICAL: every ThemeExtension a widget reads via context.* MUST appear in the
// `extensions` list below. `AppColorsTheme.of(context)` uses `!` — an unregistered
// token throws at the first call site, not at startup. Add a token => update both
// its class file AND this list.
import 'package:flutter/material.dart';
import 'package:app/design_system/theme/app_color.dart';
import 'package:app/design_system/theme/app_colors_theme.dart';

// --- Typography token group ---------------------------------------------------
@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  const AppTextTheme._({
    required this.headingLarge,
    required this.titleMedium,
    required this.bodyMedium,
    required this.buttonMini,
  });

  static const AppTextTheme standard = AppTextTheme._(
    headingLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
    buttonMini: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.0),
  );

  final TextStyle headingLarge;
  final TextStyle titleMedium;
  final TextStyle bodyMedium;
  final TextStyle buttonMini;

  static AppTextTheme of(BuildContext context) => Theme.of(context).extension<AppTextTheme>()!;
  static AppTextTheme? maybeOf(BuildContext context) => Theme.of(context).extension<AppTextTheme>();

  @override
  AppTextTheme copyWith({
    TextStyle? headingLarge,
    TextStyle? titleMedium,
    TextStyle? bodyMedium,
    TextStyle? buttonMini,
  }) {
    return AppTextTheme._(
      headingLarge: headingLarge ?? this.headingLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      buttonMini: buttonMini ?? this.buttonMini,
    );
  }

  @override
  AppTextTheme lerp(covariant ThemeExtension<AppTextTheme>? other, double t) {
    if (other is! AppTextTheme) return this;
    return AppTextTheme._(
      headingLarge: TextStyle.lerp(headingLarge, other.headingLarge, t) ?? headingLarge,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t) ?? titleMedium,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t) ?? bodyMedium,
      buttonMini: TextStyle.lerp(buttonMini, other.buttonMini, t) ?? buttonMini,
    );
  }
}

// --- Icon tint token group ----------------------------------------------------
@immutable
class AppIconsTheme extends ThemeExtension<AppIconsTheme> {
  const AppIconsTheme._({required this.primary, required this.secondary, required this.highlight});

  static const AppIconsTheme dark = AppIconsTheme._(
    primary: AppColor.iconPrimary,
    secondary: AppColor.iconSecondary,
    highlight: AppColor.primaryPure,
  );

  final Color primary;
  final Color secondary;
  final Color highlight;

  static AppIconsTheme of(BuildContext context) => Theme.of(context).extension<AppIconsTheme>()!;
  static AppIconsTheme? maybeOf(BuildContext context) => Theme.of(context).extension<AppIconsTheme>();

  @override
  AppIconsTheme copyWith({Color? primary, Color? secondary, Color? highlight}) {
    return AppIconsTheme._(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  AppIconsTheme lerp(covariant ThemeExtension<AppIconsTheme>? other, double t) {
    if (other is! AppIconsTheme) return this;
    return AppIconsTheme._(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
    );
  }
}

// --- Decoration token group ---------------------------------------------------
@immutable
class AppDecorationTheme extends ThemeExtension<AppDecorationTheme> {
  const AppDecorationTheme._({required this.card, required this.auxiliary});

  static final AppDecorationTheme dark = AppDecorationTheme._(
    card: BoxDecoration(
      color: AppColor.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    auxiliary: BoxDecoration(
      color: AppColor.primaryPure.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
  );

  final BoxDecoration card;
  final BoxDecoration auxiliary;

  static AppDecorationTheme of(BuildContext context) => Theme.of(context).extension<AppDecorationTheme>()!;
  static AppDecorationTheme? maybeOf(BuildContext context) => Theme.of(context).extension<AppDecorationTheme>();

  @override
  AppDecorationTheme copyWith({BoxDecoration? card, BoxDecoration? auxiliary}) {
    return AppDecorationTheme._(
      card: card ?? this.card,
      auxiliary: auxiliary ?? this.auxiliary,
    );
  }

  @override
  AppDecorationTheme lerp(covariant ThemeExtension<AppDecorationTheme>? other, double t) {
    if (other is! AppDecorationTheme) return this;
    return AppDecorationTheme._(
      card: BoxDecoration.lerp(card, other.card, t) ?? card,
      auxiliary: BoxDecoration.lerp(auxiliary, other.auxiliary, t) ?? auxiliary,
    );
  }
}

// --- Spacing scale token group (context.s) ------------------------------------
@immutable
class AppSpacingTheme extends ThemeExtension<AppSpacingTheme> {
  const AppSpacingTheme._({required this.xs, required this.sm, required this.md, required this.lg, required this.xl});

  static const AppSpacingTheme standard = AppSpacingTheme._(xs: 4, sm: 8, md: 16, lg: 24, xl: 32);

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  static AppSpacingTheme of(BuildContext context) => Theme.of(context).extension<AppSpacingTheme>()!;
  static AppSpacingTheme? maybeOf(BuildContext context) => Theme.of(context).extension<AppSpacingTheme>();

  @override
  AppSpacingTheme copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) {
    return AppSpacingTheme._(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  AppSpacingTheme lerp(covariant ThemeExtension<AppSpacingTheme>? other, double t) {
    if (other is! AppSpacingTheme) return this;
    return AppSpacingTheme._(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

// --- ThemeData assembly -------------------------------------------------------
// One ThemeData per brightness/brand. Every token group is registered ONCE here.
// A light/alternate theme = a parallel ThemeData with the same `extensions` shape
// but the `.light` instances swapped in.
final ThemeData appDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColor.background,
  splashFactory: NoSplash.splashFactory,
  colorScheme: const ColorScheme.dark(
    primary: AppColor.primaryPure,
    surface: AppColor.surface,
  ),
  extensions: const <ThemeExtension<dynamic>>[
    AppColorsTheme.dark,
    AppTextTheme.standard,
    AppIconsTheme.dark,
    AppSpacingTheme.standard,
  ],
).copyWith(
  // BoxDecoration.lerp / withValues make AppDecorationTheme non-const, so it is
  // attached after the const list rather than inlined above.
  extensions: <ThemeExtension<dynamic>>[
    AppColorsTheme.dark,
    AppTextTheme.standard,
    AppIconsTheme.dark,
    AppSpacingTheme.standard,
    AppDecorationTheme.dark,
  ],
);

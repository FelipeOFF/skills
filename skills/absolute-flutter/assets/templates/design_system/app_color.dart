// lib/design_system/theme/app_color.dart
//
// THE single place raw hex literals live. Every palette token maps a SEMANTIC
// name onto one of these; widgets NEVER read AppColor directly (go through a
// ThemeExtension palette via context.*). Changing a brand hex here ripples
// through the tokens — never through call sites — so this class is the refactor
// choke-point and the single source of truth for raw color.
//
// Private `_()` constructor: AppColor is a namespace, never instantiated.
// `@protected` const fields: a by-convention guard that even inside the library
// you reach color through palettes, not by poking AppColor.* into a widget.
import 'package:flutter/material.dart';

@immutable
class AppColor {
  const AppColor._();

  // Brand / accent.
  @protected
  static const Color primaryPure = Color(0xFF5B5BFF);
  @protected
  static const Color primaryDark = Color(0xFF3A3AD1);
  @protected
  static const Color primaryLight = Color(0xFF8E8EFF);

  // Neutrals as a MaterialColor swatch, so `.shade100..700` works on the token.
  @protected
  static const MaterialColor neutral = MaterialColor(0xFF27262D, <int, Color>{
    100: Color(0xFFEDEDED),
    300: Color(0xFFBDBDBD),
    500: Color(0xFF27262D),
    600: Color(0xFF1C1B21),
    700: Color(0xFF111010),
  });

  // Surfaces / feedback.
  @protected
  static const Color background = Color(0xFF0E0E12);
  @protected
  static const Color surface = Color(0xFF17171C);
  @protected
  static const Color success = Color(0xFF2ECC71);
  @protected
  static const Color danger = Color(0xFFE74C3C);

  // Icon tints.
  @protected
  static const Color iconPrimary = Color(0xFFFFFFFF);
  @protected
  static const Color iconSecondary = Color(0xFF9A9AA5);
}

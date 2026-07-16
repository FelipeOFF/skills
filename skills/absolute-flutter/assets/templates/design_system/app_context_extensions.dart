// lib/design_system/theme/app_context_extensions.dart
//
// THE public token surface — one `extension on BuildContext` that every widget
// reaches through. Instead of `Theme.of(context).extension<AppColorsTheme>()!`
// at every call site, a widget writes `context.colors.primary`. Short, greppable,
// refactor-safe, and the ENFORCED access path: widgets never touch AppColor or
// Theme.of directly.
//
// This file is a NORMAL import (it can pull in l10n/other libs). Keep each getter
// a thin delegate to a ThemeExtension's `of(this)`. Adding a token group = add
// its getter here AND register the extension in app_theme.dart's `extensions:`.
import 'package:flutter/material.dart';
import 'package:app/design_system/theme/app_colors_theme.dart';
import 'package:app/design_system/theme/app_theme.dart';

extension AppContextExtensions on BuildContext {
  /// Color tokens — `context.colors.primary`, `context.colors.neutral.shade600`.
  AppColorsTheme get colors => AppColorsTheme.of(this);

  /// Typography tokens — `context.text.bodyMedium`.
  AppTextTheme get text => AppTextTheme.of(this);

  /// Icon tint tokens — `context.icons.highlight`.
  AppIconsTheme get icons => AppIconsTheme.of(this);

  /// Decoration tokens — `context.decoration.card`.
  AppDecorationTheme get decoration => AppDecorationTheme.of(this);

  /// Spacing scale — `context.s.md`. Short on purpose; it is read constantly.
  AppSpacingTheme get s => AppSpacingTheme.of(this);
}

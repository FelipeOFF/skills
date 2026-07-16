// lib/common/util/context_capability_ext.dart
//
// BuildContext capability extensions — the glue that lets a widget reach
// navigation, DI singletons, design tokens, MediaQuery sizing, and snackbars
// fluently (`context.colors`, `context.analytics`, `context.showSnackBar(...)`).
//
// KEEP CAPABILITY HELPERS AND TOKEN ACCESS SPLITTABLE. In a real app this file
// often splits into context_nav_ext.dart / context_design_ext.dart /
// build_context_analytics_ext.dart to limit import fan-out — a single
// BuildContext file that imports routers + DI + design system + l10n couples
// everything. Here they share one file for the skeleton; split as it grows.
import 'package:flutter/material.dart';

import 'package:app/design_system/theme/app_colors_theme.dart';
import 'package:app/di/app_di.dart';

/// Design-token access — the single sanctioned way to read theme tokens.
/// Widgets call `context.colors.primary`, never `Theme.of(context)` directly,
/// so a token rename is one edit here.
extension ContextDesignExt on BuildContext {
  /// The registered color palette (a `ThemeExtension`). `of(this)` asserts the
  /// palette is installed in `ThemeData.extensions`.
  AppColorsTheme get colors => AppColorsTheme.of(this);
}

/// DI access from a widget without constructor plumbing. Pulls a singleton from
/// the service locator. One getter per service the UI needs to reach.
extension ContextDiExt on BuildContext {
  /// Quick access to the analytics service from the DI container.
  ///
  /// ```dart
  /// onTap: () => context.analytics.logEvent('item_opened');
  /// ```
  AnalyticsService get analytics => AppDI.it<AnalyticsService>();
}

/// Typed navigation + sizing + snackbar glue. Methods that take args; getters
/// for derived sizes.
extension ContextNavExt on BuildContext {
  /// Pushes the detail route with a typed path parameter, instead of a raw
  /// string route literal at the call site.
  Future<void> pushToDetail(String id) =>
      Navigator.of(this).pushNamed('/detail', arguments: id);

  /// Replaces the current route (e.g. after login) — no back entry.
  Future<void> replaceWith(String routeName, {Object? arguments}) =>
      Navigator.of(this).pushReplacementNamed(routeName, arguments: arguments);

  /// Shows a one-line snackbar without the caller touching ScaffoldMessenger.
  void showSnackBar(String message) =>
      ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));

  /// Half-width-minus-gutter tile size for a 2-column grid. Derived MediaQuery
  /// value exposed as a getter so layout code reads `context.squareTileSize`.
  double get squareTileSize => (MediaQuery.of(this).size.width - 44) / 2;
}

/// Stand-in for the real DI-registered analytics contract. Replace with the
/// app's actual service interface; the extension above resolves it from
/// [AppDI].
abstract class AnalyticsService {
  void logEvent(String event, {Map<String, Object?> properties});
}

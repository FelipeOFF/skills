// lib/navigation/app_router.dart
//
// THE route table. One enum value per screen, carrying its `path`, `name`, and
// the metadata flags everything else derives from:
//   - requiresAuthentication : drives the unauthenticated allow-list (and any
//                              redirect gating) for free.
//   - isBottomNavigation     : marks the shell tabs (see shell_route.dart).
//
// Path and name are NEVER typed as raw strings at a call site — always via the
// enum (`AppRouter.userProfile.name`). This is the single source of truth: flip
// an auth/bottom-nav flag here and the allow-list, the shell tab set, and the
// deep-link resolver all follow.
//
// `AppRouter.config` is the built root GoRouter (see router.dart). It lives here
// as a static so `app_widget.dart` can wire `MaterialApp.router(routerConfig:
// AppRouter.config)` against one symbol.
//
// Rename anchors: itemDetails / userProfile / mainHome are example routes —
// rename, add, or remove enum values to match the real route table.
import 'package:go_router/go_router.dart';

import 'package:app/navigation/router.dart';

enum AppRouter {
  // Public routes (requiresAuthentication: false derives the allow-list).
  initial('/initial', 'Initial', requiresAuthentication: false),
  login('/login', 'Login', requiresAuthentication: false),

  // Bottom-navigation shell tabs (isBottomNavigation: true).
  mainHome('/main/home', 'Home', isBottomNavigation: true),
  mainList('/main/list', 'List', isBottomNavigation: true),

  // Authenticated detail routes. Path params use `:param`.
  itemDetails('/item-details/:itemId', 'ItemDetails'),
  userProfile('/user/:userId', 'UserProfile'),
  itemAction('/item/action/:itemId/:actionId', 'ItemAction');

  const AppRouter(
    this.path,
    this.name, {
    this.isBottomNavigation = false,
    this.requiresAuthentication = true,
  });

  final String path;
  final String name;
  final bool isBottomNavigation;
  final bool requiresAuthentication;

  /// The built root GoRouter, wired in router.dart. `app_widget.dart` reads this.
  static GoRouter get config => buildAppRouter();

  /// Every screen flagged as a bottom-nav tab — used to build the shell.
  static List<AppRouter> get bottomNavigationRouters =>
      AppRouter.values.where((e) => e.isBottomNavigation).toList();

  /// Every public screen — the inverse of "requires auth".
  static List<AppRouter> get unauthenticatedRouters =>
      AppRouter.values.where((e) => !e.requiresAuthentication).toList();

  /// The allow-list of public paths, derived (never hand-maintained).
  static List<String> get unauthenticatedPaths =>
      unauthenticatedRouters.map((r) => r.path).toList();
}

/// Resolve a raw `path` or `name` string back to its enum value. Used by the
/// deep-link resolver to turn an incoming URL into a typed [AppRouter].
extension AppRouterUtilityStringExt on String {
  AppRouter get toAppRouter =>
      AppRouter.values.firstWhere((e) => e.path == this || e.name == this);
}

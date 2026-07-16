// lib/common/util/nav_context_ext.dart
//
// Typed, semantic navigation at the call site. Instead of stringly-typed
// `pushNamed('UserProfile', pathParameters: {'userId': id})` scattered across
// the app, call `context.pushToUserProfile(id)`. Each method centralizes ONE
// route's param construction (path/query params, `extra`), so changing a route
// signature touches exactly one method here.
//
// Always go through `AppRouter.x.name` (NOT `.path`) for `pushNamed`. `.path` is
// for `go(...)` / `initialLocation` / startsWith checks only.
//
// Rename anchors: pushToExample / pushToUserProfile / pushToItemDetail are
// example methods — add one per real route.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:app/navigation/app_router.dart';

extension NavContextExt on BuildContext {
  /// Resolve a route to its concrete location string (for `go`-style calls or
  /// `popUntil` predicates) without pushing.
  String namedLocationWithAppRouter(
    AppRouter router, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
  }) =>
      namedLocation(
        router.name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      );

  /// Replace the current route with [router]'s screen. Use for post-login /
  /// logout transitions where you do not want a back stack entry.
  void pushReplacementWithAppRouter(AppRouter router, {Object? extra}) =>
      pushReplacementNamed(router.name, extra: extra);

  // ---- Semantic typed push methods (preferred at every call site) ----

  /// Push a simple, param-less example screen.
  Future<void> pushToExample() => pushNamed(AppRouter.itemAction.name);

  /// Push the user profile detail, supplying the required path param.
  Future<void> pushToUserProfile(String userId) => pushNamed(
        AppRouter.userProfile.name,
        pathParameters: <String, String>{'userId': userId},
      );

  /// Push the item detail. `extra` carries the already-loaded DTO so the detail
  /// screen can render instantly without a refetch (see Gotchas: `extra` does
  /// NOT survive a cold-start deep link — only path/query params do).
  Future<void> pushToItemDetail(String itemId, {Object? extra}) => pushNamed(
        AppRouter.itemDetails.name,
        pathParameters: <String, String>{'itemId': itemId},
        extra: extra,
      );
}

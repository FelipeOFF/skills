// lib/navigation/base_navigation.dart
//
// The per-feature route contract. Each feature owns ONE class that extends
// `BaseNavigation` and returns its own `GoRoute`s (built with `AppGoRoute`).
// Adding a feature = add one navigation class + one line in `AppNavigations`
// (see app_navigations.dart) — the root router file never grows.
//
// `NavigationKey` holds the two navigator keys: the root key (detail routes
// pushed above the shell) and the main/shell key (bottom-nav tab stack). Routes
// inside the shell set `parentNavigatorKey: NavigationKey.mainNavigatorKey`.
//
// Example below: rename `FeatureNavigation` / `FeaturePage` to the real feature.
// The View resolves its own Controller from get_it inside `BaseState` (see
// base_state.dart / 08-mvvm-rxnotifier.md) — so the route `builder` constructs a
// `const FeaturePage()` and passes only ROUTE inputs (path/query params) to it.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:app/feature/feature/page/feature_page.dart';
import 'package:app/navigation/app_router.dart';
import 'package:app/navigation/helper/app_go_route.dart';
import 'package:app/navigation/helper/transitions.dart';

/// The contract every feature navigation implements: return this feature's
/// routes. `AppNavigations` flattens all of them into the router's `routes:`.
abstract class BaseNavigation {
  List<RouteBase> get listOfPages;
}

/// Flattens a list of feature navigations into one flat `RouteBase` list.
extension BaseNavigationListExt on List<BaseNavigation> {
  List<RouteBase> get expandToRoutes =>
      <RouteBase>[for (final nav in this) ...nav.listOfPages];
}

/// The navigator keys. Root key = above the shell (detail routes); main key =
/// the bottom-nav shell's own navigator (the tab stack).
class NavigationKey {
  NavigationKey._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'Root');
  static final GlobalKey<NavigatorState> mainNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'Main');
}

/// A feature navigation. Each feature ships one of these. The View is a
/// `BaseState<FeaturePage, FeatureController>` that resolves its own Controller
/// from DI (see 08-mvvm-rxnotifier.md), so the builder only forwards route
/// inputs (path/query params) into the page constructor.
class FeatureNavigation extends BaseNavigation {
  @override
  List<RouteBase> get listOfPages => <RouteBase>[
        AppGoRoute(
          router: AppRouter.itemDetails,
          defaultTransition: Transitions.slideLeft,
          builder: (context, state) {
            // Path params are always String; coerce when you need another type.
            final itemId = state.pathParameters['itemId'] ?? '';
            return FeaturePage(itemId: itemId);
          },
        ),
      ];
}

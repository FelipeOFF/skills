// lib/navigation/app_navigations.dart
//
// The SINGLE registration point. Lists every feature navigation once and
// flattens them (via `expandToRoutes`) into the flat `List<RouteBase>` the root
// GoRouter consumes. Adding a feature = add one line here. The root router file
// (router.dart) never changes as features grow.
//
// Rename anchors: swap the example feature navigations for the real ones.
import 'package:go_router/go_router.dart';

import 'package:app/navigation/base_navigation.dart';
import 'package:app/navigation/feature/auth_navigation.dart';
import 'package:app/navigation/feature/feature_navigation.dart';
import 'package:app/navigation/feature/main_navigation.dart';

class AppNavigations {
  AppNavigations._();

  /// One entry per feature. Order is irrelevant except that the shell route
  /// (MainNavigation) must be present so its tab paths resolve.
  static final List<RouteBase> listOfNavigation = <BaseNavigation>[
    AuthNavigation(),
    MainNavigation(),
    FeatureNavigation(),
    // ...one line per feature
  ].expandToRoutes;
}

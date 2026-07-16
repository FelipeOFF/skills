// lib/navigation/helper/app_go_route.dart
//
// A `GoRoute` subclass that takes an `AppRouter` enum value (for path + name)
// and a `Transitions` enum (for the animation), then auto-builds a
// `CustomTransitionPage` from the `builder`. Features declare a `builder` and a
// transition type — never a hand-written `pageBuilder` — so transition
// boilerplate lives in exactly one place.
//
// Pass an explicit `pageBuilder` only when you need a special page (e.g.
// `NoTransitionPage` for a shell tab); it wins over the auto-wrap.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:app/navigation/app_router.dart';
import 'package:app/navigation/helper/transitions.dart';

class AppGoRoute<T> extends GoRoute {
  AppGoRoute({
    required AppRouter router,
    GoRouterWidgetBuilder? builder,
    GoRouterPageBuilder? pageBuilder,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    GoRouterRedirect? redirect,
    List<RouteBase> routes = const <RouteBase>[],
    this.defaultTransition = Transitions.slideLeft,
    this.transitionDuration = const Duration(milliseconds: 200),
  }) : super(
          path: router.path,
          name: router.name,
          builder: builder,
          // When no explicit pageBuilder is given but a builder is, wrap the
          // builder's widget in the transition the route declared.
          pageBuilder: pageBuilder ??
              (builder != null
                  ? (context, state) => TransitionsFactory(defaultTransition).transitionBuilder<T>(
                        builder(context, state),
                        transitionDuration: transitionDuration,
                      )
                  : null),
          parentNavigatorKey: parentNavigatorKey,
          redirect: redirect,
          routes: routes,
        );

  final Transitions defaultTransition;
  final Duration transitionDuration;
}

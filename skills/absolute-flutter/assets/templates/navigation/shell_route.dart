// lib/navigation/feature/main_navigation.dart
//
// The bottom-navigation shell. A `ShellRoute` wraps the tab pages in a shared
// scaffold (`MainPage`, which renders the bottom bar + the `child` stack). Each
// tab is an `AppGoRoute` flagged `isBottomNavigation` in the enum and pinned to
// the shell's `mainNavigatorKey` so the tab stack lives UNDER the shell while
// detail routes push ABOVE it on the root navigator.
//
// Tab pages use `NoTransitionPage` (instant tab switches, no slide). Each page
// is a `const` View whose `BaseState` resolves its own Controller from DI.
//
// Rename anchors: HomePage / SettingsPage are example tabs — match them to the
// real bottom-nav screens and the `AppRouter.mainXxx` enum values.
import 'package:go_router/go_router.dart';

import 'package:app/feature/home/page/home_page.dart';
import 'package:app/feature/main/page/main_page.dart';
import 'package:app/feature/settings/page/settings_page.dart';
import 'package:app/navigation/app_router.dart';
import 'package:app/navigation/base_navigation.dart';
import 'package:app/navigation/helper/app_go_route.dart';

class MainNavigation extends BaseNavigation {
  @override
  List<RouteBase> get listOfPages => <RouteBase>[
        ShellRoute(
          navigatorKey: NavigationKey.mainNavigatorKey,
          builder: (context, state, child) => MainPage(child: child),
          routes: <RouteBase>[
            AppGoRoute(
              router: AppRouter.mainHome,
              parentNavigatorKey: NavigationKey.mainNavigatorKey,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomePage(),
              ),
            ),
            AppGoRoute(
              router: AppRouter.mainList,
              parentNavigatorKey: NavigationKey.mainNavigatorKey,
              pageBuilder: (context, state) {
                // Query params are always String?; coerce what you need.
                final query = state.uri.queryParameters['q'];
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
                return NoTransitionPage(child: SettingsPage(query: query, tab: tab));
              },
            ),
          ],
        ),
      ];
}

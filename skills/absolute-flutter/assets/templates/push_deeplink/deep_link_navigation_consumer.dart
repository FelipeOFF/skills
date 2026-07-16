import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:app/navigation/app_routers.dart';
import 'package:app/service/deep_link/cubit/deep_link_navigation_cubit.dart';
import 'package:app/service/deep_link/models/deep_link_data.dart';

/// Root consumer that turns cubit states into `go_router` navigation. Wrap your
/// app shell's `child` with this (it sits BELOW the `GoRouter` so a context with
/// the router is available).
///
/// Rename anchors: none. `goRouter` is your app-global `GoRouter` instance.
class DeepLinkNavigationConsumer extends StatefulWidget {
  const DeepLinkNavigationConsumer({super.key, required this.goRouter, required this.child});

  final GoRouter goRouter;
  final Widget child;

  @override
  State<DeepLinkNavigationConsumer> createState() => _DeepLinkNavigationConsumerState();
}

class _DeepLinkNavigationConsumerState extends State<DeepLinkNavigationConsumer> {
  DeepLinkData? _lastNavigated;
  DateTime _lastNavigatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  String get _location => widget.goRouter.routerDelegate.currentConfiguration.uri.toString();

  @override
  Widget build(BuildContext context) {
    // listenWhen on status ONLY: avoids reacting to non-status copyWith updates
    // (e.g. pending-link changes) and nav loops.
    return BlocListener<DeepLinkNavigationCubit, DeepLinkNavState>(
      listenWhen: (DeepLinkNavState p, DeepLinkNavState c) => p.status != c.status,
      listener: _onState,
      child: widget.child,
    );
  }

  void _onState(BuildContext context, DeepLinkNavState state) {
    final DeepLinkNavigationCubit cubit = context.read<DeepLinkNavigationCubit>();
    switch (state.status) {
      case DeepLinkNavStatus.processing:
      case DeepLinkNavStatus.awaitingAuthentication:
        // Feed the cubit the current router location so it can decide.
        cubit.process(_location);
      case DeepLinkNavStatus.navigationReady:
        final DeepLinkData? data = state.deepLinkData;
        if (data != null && !_isDuplicate(data)) {
          _navigate(data);
          _markNavigated(data);
        }
        cubit.clearPendingNavigation();
      case DeepLinkNavStatus.initial:
      case DeepLinkNavStatus.idle:
      case DeepLinkNavStatus.navigationFailed:
      case DeepLinkNavStatus.navigationSkippedUnauthenticated:
        break;
    }
  }

  void _navigate(DeepLinkData data) {
    final GoRouter router = widget.goRouter;
    if (data.route.isBottomNavigation) {
      router.go(
        Uri.parse(data.route.path)
            .replace(queryParameters: data.queryParameters.map((String k, dynamic v) => MapEntry<String, String>(k, '$v')))
            .toString(),
      );
    } else if (_outsideAuthArea(_location)) {
      // Establish the authenticated stack first, THEN push the deep route after
      // a short delay so the auth navigation stack exists.
      router.go(AppRouter.home.path);
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        router.pushNamed(
          data.route.name,
          pathParameters: data.pathParameters,
          queryParameters: data.queryParameters.map((String k, dynamic v) => MapEntry<String, String>(k, '$v')),
          extra: data,
        );
      });
    } else {
      router.pushNamed(
        data.route.name,
        pathParameters: data.pathParameters,
        queryParameters: data.queryParameters.map((String k, dynamic v) => MapEntry<String, String>(k, '$v')),
        extra: data,
      );
    }
  }

  bool _outsideAuthArea(String location) =>
      AppRouter.unauthenticatedPaths.any((String p) => location.startsWith(p));

  // De-dupe: ignore identical route+params within 2s (Branch / go_router can
  // double-fire).
  bool _isDuplicate(DeepLinkData data) {
    final bool sameLink = _lastNavigated == data;
    final bool recent = DateTime.now().difference(_lastNavigatedAt) < const Duration(seconds: 2);
    return sameLink && recent;
  }

  void _markNavigated(DeepLinkData data) {
    _lastNavigated = data;
    _lastNavigatedAt = DateTime.now();
  }
}

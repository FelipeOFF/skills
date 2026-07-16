// lib/navigation/router.dart
//
// The ROOT GoRouter. `app_router.dart` exposes it as `AppRouter.config`; this
// file builds it. It does three things and nothing else:
//   1. assembles routes from `AppNavigations.listOfNavigation` (the per-feature
//      aggregator) — this file never lists routes itself,
//   2. installs a `redirect` used for deep-link ORCHESTRATION, not gating: it
//      returns `null` (no hard redirect) and only schedules deferred deep-link
//      processing post-frame,
//   3. installs the deep-link hook: an `rxObserver` over a
//      `DeepLinkController` (rx_notifier) that drives `go` / `pushNamed` when a
//      pending deep link becomes ready.
//
// rx_notifier is canonical here: deep-link state is a `DeepLinkController extends
// BaseController` exposing an `RxNotifier<DeepLinkState>`; the root View observes
// it with `rxObserver`. (Legacy aside: an earlier variant carried this in a
// Cubit consumed by a `BlocListener` — the rx_notifier observer replaces it.)
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rx_notifier/rx_notifier.dart';

import 'package:app/di/app_di.dart';
import 'package:app/feature/deep_link/controller/deep_link_controller.dart';
import 'package:app/navigation/app_navigations.dart';
import 'package:app/navigation/app_router.dart';
import 'package:app/navigation/base_navigation.dart';

/// The single root GoRouter. Built once and cached so `AppRouter.config`
/// (in app_router.dart) and every `go` / `pushNamed` share one instance.
GoRouter buildAppRouter() => _appRouter;

final GoRouter _appRouter = GoRouter(
  navigatorKey: NavigationKey.rootNavigatorKey,
  initialLocation: AppRouter.initial.path,
  routes: AppNavigations.listOfNavigation,
  debugLogDiagnostics: true,
  redirect: _redirect,
);

/// Non-blocking redirect. It NEVER returns a destination — it returns `null`
/// (no hard redirect) and only schedules deferred deep-link processing on the
/// next frame. Hard auth gating is implicit: the only public routes are the
/// initial/login screens (derived from `AppRouter.unauthenticatedPaths`), and
/// the deep-link hook routes through `mainHome` to establish auth context
/// before pushing a protected target.
///
/// Keep this cheap and side-effect-free except the post-frame schedule —
/// `redirect` runs on EVERY navigation.
String? _redirect(BuildContext context, GoRouterState state) {
  final controller = AppDI.it<DeepLinkController>();
  final pending = controller.pendingDeepLink;
  if (pending != null &&
      controller.status == DeepLinkStatus.awaitingAuthentication &&
      !isOutsideAuthenticatedArea(state.uri.path)) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.process(state.uri.path),
    );
  }
  return null; // no hard redirect — orchestration only
}

/// True when `location` is one of the public (unauthenticated) paths. Drives the
/// "establish auth context first" branch in the deep-link hook.
bool isOutsideAuthenticatedArea(String location) =>
    AppRouter.unauthenticatedPaths.any((p) => location.startsWith(p));

/// The deep-link hook. Mount this near the app root (e.g. in `app_widget`'s
/// `builder`) so it observes the `DeepLinkController` and drives the router when
/// a pending link becomes ready. `rxObserver` is the rx_notifier imperative twin
/// of `RxBuilder`: it re-runs on every change of the notifiers it reads and
/// returns an `RxDisposer` the host State must call in `dispose`.
class DeepLinkHook extends StatefulWidget {
  const DeepLinkHook({required this.child, super.key});

  final Widget child;

  @override
  State<DeepLinkHook> createState() => _DeepLinkHookState();
}

class _DeepLinkHookState extends State<DeepLinkHook> {
  final DeepLinkController _controller = AppDI.it<DeepLinkController>();
  late final RxDisposer _dispose;

  // Dedup identical deep links within a short window so a re-fire does not push
  // the same route twice.
  String? _lastKey;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    _controller.onInit();
    _controller.initialize();
    _dispose = rxObserver<DeepLinkStatus>(() => _handle(_controller.status));
  }

  void _handle(DeepLinkStatus status) {
    final router = _appRouter;
    switch (status) {
      case DeepLinkStatus.processing:
      case DeepLinkStatus.awaitingAuthentication:
        _controller.process(router.state.uri.path);
      case DeepLinkStatus.navigationReady:
        final data = _controller.deepLinkData;
        if (data == null || !mounted) return;

        // Dedup identical links inside a 2s window.
        final key = '${data.route.name}|${data.pathParameters}|${data.queryParameters}';
        final now = DateTime.now();
        if (_lastKey == key && _lastTime != null && now.difference(_lastTime!).inSeconds < 2) {
          _controller.clearPendingNavigation();
          return;
        }
        _lastKey = key;
        _lastTime = now;

        if (data.route.isBottomNavigation) {
          // Bottom-nav targets REPLACE (go), so back behaviour stays correct.
          router.go(data.route.path);
        } else if (isOutsideAuthenticatedArea(router.state.uri.path)) {
          // Establish authenticated context first, THEN push the protected target.
          router.go(AppRouter.mainHome.path);
          Future<void>.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            router.pushNamed(
              data.route.name,
              pathParameters: data.pathParameters,
              queryParameters: data.queryParameters,
              extra: data,
            );
          });
        } else {
          // Already authenticated: push the detail route onto the stack.
          router.pushNamed(
            data.route.name,
            pathParameters: data.pathParameters,
            queryParameters: data.queryParameters,
            extra: data,
          );
        }
        _controller.clearPendingNavigation();
      case DeepLinkStatus.idle:
        break;
    }
  }

  @override
  void dispose() {
    _dispose(); // RxDisposer is callable -> tears down the observer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

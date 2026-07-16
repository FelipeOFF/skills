import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rx_notifier/rx_notifier.dart';

import 'package:app/common/base/base_controller.dart';
import 'package:app/common/message/generic_message.dart';
import 'package:app/di/app_di.dart';
import 'package:app/navigation/app_routers.dart';

/// The View base for the rx_notifier MVVM stack. A page's private `State`
/// extends `BaseState<ThePage, TheController>`; this base does three things so
/// no feature has to repeat them:
///
///   1. **DI**: pulls the Controller from the global container in a field
///      initializer, so the View never news-up its ViewModel.
///   2. **Lifecycle**: calls `controller.onInit()` in `initState` (which
///      allocates the base notifiers BEFORE any reactive read) and
///      `controller.dispose()` in `dispose` (guarded by [disposeController]).
///   3. **Global reactive side effects**: an `rxObserver` for the error/dialog
///      `message` channel and one for the force-logout `goToInitialPage`
///      redirect. `rxObserver` is the imperative twin of `RxBuilder` — it runs
///      now and again on every change of the notifiers it read, and returns an
///      `RxDisposer` that MUST be called in `dispose`.
abstract class BaseState<T extends StatefulWidget, C extends BaseController> extends State<T> {
  /// One Controller per State, pulled from DI. `registerFactory` gives each
  /// page a fresh Controller with fresh `RxNotifier` state.
  final C controller = AppDI.it<C>();

  /// Whether this State owns the Controller's lifetime. Override to `false`
  /// when the page borrows a shared/long-lived Controller it must not dispose.
  bool get disposeController => true;

  late final RxDisposer _messageDispose;
  late final RxDisposer _redirectDispose;

  @override
  void initState() {
    super.initState();
    controller.onInit(); // allocates base notifiers before any reactive read

    // Global error/dialog surface: show the message, then clear it.
    _messageDispose = rxObserver<GenericMessage?>(() async {
      final GenericMessage? message = controller.message;
      if (message != null && message is! EmptyMessage) {
        await message.show(context);
        controller.message = null;
      }
    });

    // Force-logout redirect: replace the route with the initial page.
    _redirectDispose = rxObserver<bool?>(() {
      if (controller.goToInitialPage == true && mounted) {
        context.pushReplacement(AppRouter.initial.path);
      }
    });
  }

  @override
  void dispose() {
    _messageDispose(); // RxDisposer is callable -> tears down the observer
    _redirectDispose();
    if (disposeController) controller.dispose();
    super.dispose();
  }
}

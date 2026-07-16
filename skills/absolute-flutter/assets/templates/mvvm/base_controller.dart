import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';
import 'package:rx_notifier/rx_notifier.dart';

import 'package:app/common/message/generic_message.dart';
import 'package:app/common/util/either_helpers.dart';
import 'package:app/di/app_di.dart';
import 'package:app/domain/abstract_use_case.dart';
import 'package:app/domain/app_error.dart';
import 'package:app/domain/auth/logout_use_case.dart';

/// Signature for the per-call error hook. Receives the raw [AppError] and a
/// default [GenericMessage] the ladder already built; return the message to
/// surface, or `null` to suppress (e.g. after dispose, or to swallow on a
/// silent background refresh).
typedef CallBackError = GenericMessage? Function(AppError error, GenericMessage defaultMessage);

/// The ViewModel base for the rx_notifier MVVM stack. A feature Controller
/// extends this, exposes its UI state as private `RxNotifier` fields behind
/// getter/setter pairs, and calls [execSingle] / [execCallback] to run use
/// cases. This base owns three cross-cutting reactive channels — `isLoading`,
/// `message`, `goToInitialPage` — and the execution ladder that toggles
/// loading, folds `Either<AppError, T>`, routes errors into `message`, and
/// special-cases `Logout` into a force-logout + redirect.
///
/// WHY a base mixin and not a Cubit: every Controller gets uniform loading +
/// error + logout handling for free, with no event/state boilerplate. The View
/// reads the reactive getters inside `RxBuilder`; `BaseState` renders `message`
/// and reacts to `goToInitialPage` globally.
abstract class BaseController {
  bool _isDisposed = false;

  /// True once [dispose] ran. Guard every async state write with this so an
  /// in-flight request that completes after the page is gone does not write
  /// into a disposed notifier.
  bool get isDisposed => _isDisposed;

  // Base reactive channels are created lazily in [onInit] (called by
  // BaseState.initState) so a Controller resolved by DI but never mounted does
  // not allocate notifiers it will never dispose.
  RxNotifier<GenericMessage?>? _message;
  RxNotifier<bool?>? _isLoading;
  RxNotifier<bool?>? _goToInitialPage;

  /// Global error/dialog channel. `BaseState` observes this and shows the
  /// message, then clears it. Setting it is a no-op once disposed.
  GenericMessage? get message => _message?.value;
  set message(GenericMessage? value) {
    if (!isDisposed) _message?.value = value;
  }

  /// Inherited loading flag. The ladder flips it around a use case unless
  /// `showLoading: false` is passed. Read it inside an `RxBuilder` to show a
  /// spinner. No-op once disposed.
  bool? get isLoading => _isLoading?.value;
  set isLoading(bool? value) {
    if (!isDisposed) _isLoading?.value = value;
  }

  /// Force-logout redirect channel. The ladder sets this on a `Logout` error;
  /// `BaseState` observes it and replaces the route with the initial page.
  bool? get goToInitialPage => _goToInitialPage?.value;
  set goToInitialPage(bool? value) {
    if (!isDisposed) _goToInitialPage?.value = value;
  }

  /// Called by `BaseState.initState` BEFORE any reactive read. Allocates the
  /// base notifiers. Override to seed feature state, but always call
  /// `super.onInit()` first.
  @mustCallSuper
  void onInit() {
    _message = RxNotifier<GenericMessage?>(const EmptyMessage());
    _isLoading = RxNotifier<bool?>(null);
    _goToInitialPage = RxNotifier<bool?>(null);
  }

  /// Run one use case and return its success value, or `null` when it failed
  /// (the error has already been routed into [message]). The Controller never
  /// unwraps the `Either` by hand — this is the single fold point.
  ///
  /// - [showLoading] toggles [isLoading] around the call; pass `false` to drive
  ///   a feature-specific loading flag yourself (pagination, pull-to-refresh).
  /// - [mapError] customizes or suppresses the surfaced message per call.
  /// - [forceRefresh] plumbs through to the use case's cache hook.
  Future<R?> execSingle<P, R>(
    P value,
    AbstractUseCase<P, R> useCase, {
    CallBackError? mapError,
    bool showLoading = true,
    bool? forceRefresh = false,
  }) async {
    if (showLoading) isLoading = true;
    try {
      final Either<AppError, R> result = await useCase(value, forceRefresh: forceRefresh ?? false);
      if (result.isLeft()) {
        _resolveError(result.unwrapLeft, mapError);
        return null;
      }
      return result.unwrapRight;
    } finally {
      if (showLoading) isLoading = false;
    }
  }

  /// Run a use case and invoke [onSuccess] with its value on the happy path.
  /// Use this when the result feeds a side effect (navigate, toast) rather than
  /// being stored as state. Same loading/error/logout semantics as [execSingle].
  Future<void> execCallback<P, R>(
    P value,
    AbstractUseCase<P, R> useCase, {
    required void Function(R value) onSuccess,
    CallBackError? mapError,
    bool showLoading = true,
    bool? forceRefresh = false,
  }) async {
    final R? result = await execSingle(
      value,
      useCase,
      mapError: mapError,
      showLoading: showLoading,
      forceRefresh: forceRefresh,
    );
    if (!isDisposed && result != null) onSuccess(result);
  }

  /// Single error-routing point. Translates an [AppError] into a surfaced
  /// [message], special-casing [Logout] into a force-logout + redirect.
  void _resolveError(AppError error, CallBackError? mapError) {
    if (isDisposed) return;
    if (error is Logout) {
      _handleLogout();
      return;
    }
    final GenericMessage defaultMessage = ErrorMessage(error: error);
    message = mapError != null ? mapError(error, defaultMessage) : defaultMessage;
  }

  /// On a 401/expired session: run the logout use case (resolved via the
  /// service locator — the one cross-cutting case where a Controller reaches
  /// into DI) and flip the redirect channel `BaseState` observes.
  Future<void> _handleLogout() async {
    await AppDI.it<LogoutUseCase>()(null);
    goToInitialPage = true;
  }

  /// Tears down the base notifiers. A feature Controller overrides this to
  /// dispose every `RxNotifier` it owns, then calls `await super.dispose()`.
  @mustCallSuper
  Future<void> dispose() async {
    _isDisposed = true;
    _message?.dispose();
    _isLoading?.dispose();
    _goToInitialPage?.dispose();
  }
}

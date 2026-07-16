import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/data/database/abstract_database.dart';
import 'package:app/data/database/database_keys.dart';
import 'package:app/navigation/app_routers.dart';
import 'package:app/service/deep_link/deep_link_service.dart';
import 'package:app/service/deep_link/models/deep_link_data.dart';

/// Deferred-navigation state machine.
///
/// This is a deliberate Cubit, NOT an rx_notifier Controller: it is app-global
/// cross-cutting navigation plumbing, not a screen ViewModel. Feature screens
/// still use the canonical rx_notifier `Controller` (see `08-mvvm-rxnotifier.md`).
/// The Cubit only carries this one deferred-nav concern.
///
/// Flow: a link tapped on the login screen must SURVIVE login and fire after.
/// `processing -> awaitingAuthentication -> (login) -> navigationReady`.
/// Navigation only fires inside the authenticated area; the cubit holds a
/// `pendingDeepLink` until then.
class DeepLinkNavigationCubit extends Cubit<DeepLinkNavState> {
  DeepLinkNavigationCubit(this._service, this._database) : super(const DeepLinkNavState.initial());

  final DeepLinkService _service;
  final AbstractDatabase _database;

  StreamSubscription<DeepLinkData>? _navSub;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<String?>? _storedSub;

  void initialize() {
    _navSub = _service.navigationStream.listen(_onNav, onError: _onError);
    _authSub = _database.watchKey<String>(DatabaseKeys.accessTokenKey.name).listen(_onAuthChange);
    _storedSub = _database.watchKey<String>(DatabaseKeys.storedDeepLink.name).listen(_onStoredChange);
    unawaited(_processStoredFromPreviousSession());
  }

  /// A new inbound link arrived. Hold it (`processing`) and persist as pending.
  void _onNav(DeepLinkData data) {
    if (data.isExpired) {
      logger.d('🟢 CUBIT: ignored expired link');
      return;
    }
    logger.d('🟢 CUBIT: holding link route=${data.route.name}');
    emit(DeepLinkNavState.processing(data, isAuthenticated: state.isAuthenticated, pendingDeepLink: data));
    unawaited(_savePending(data));
  }

  /// The user just logged in (token appeared) with a pending link -> resume.
  void _onAuthChange(String? token) {
    final DeepLinkData? pending = state.pendingDeepLink;
    final bool authed = token?.isNotEmpty == true;
    if (pending != null && authed && state.status == DeepLinkNavStatus.awaitingAuthentication) {
      logger.d('🟢 CUBIT: auth arrived, resuming pending link');
      emit(DeepLinkNavState.processing(pending, isAuthenticated: true, pendingDeepLink: pending));
    }
  }

  void _onStoredChange(String? raw) {
    if (raw == null || raw.isEmpty) return;
    // A link stored from another entry point (e.g. background) — re-drive it.
    unawaited(_processStoredFromPreviousSession());
  }

  /// Called by the widget tree with the CURRENT router location. Decides whether
  /// to fire (`navigationReady`) or wait for auth (`awaitingAuthentication`).
  Future<void> process(String location) async {
    if (state.status != DeepLinkNavStatus.processing &&
        state.status != DeepLinkNavStatus.awaitingAuthentication) {
      return;
    }
    final DeepLinkData? data = state.deepLinkData ?? state.pendingDeepLink;
    if (data == null) return;

    if (_inAuthenticatedArea(location)) {
      emit(DeepLinkNavState.navigationReady(data, isAuthenticated: true)); // GREEN LIGHT
    } else {
      emit(DeepLinkNavState.awaitingAuthentication(data, pendingDeepLink: data)); // WAIT
    }
  }

  Future<void> _processStoredFromPreviousSession() async {
    final DeepLinkData? stored = await _service.getStoredDeepLink();
    if (stored == null || stored.isExpired) return;
    emit(DeepLinkNavState.processing(stored, isAuthenticated: state.isAuthenticated, pendingDeepLink: stored));
  }

  /// "Authenticated" is derived from the router LOCATION, not a token flag here —
  /// keeps the cubit decoupled from auth internals.
  bool _inAuthenticatedArea(String location) =>
      !AppRouter.unauthenticatedPaths.any((String p) => location.startsWith(p));

  void clearPendingNavigation() {
    emit(state.copyWith(status: DeepLinkNavStatus.idle));
    unawaited(_savePending(null));
  }

  Future<void> _savePending(DeepLinkData? data) async {
    if (data == null) {
      await _service.clearStoredDeepLink();
    } else {
      await _service.storeDeepLink(data);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    logger.e('🟢 CUBIT: nav stream error', error: error, stackTrace: stackTrace);
    emit(state.copyWith(status: DeepLinkNavStatus.navigationFailed));
  }

  @override
  Future<void> close() {
    _navSub?.cancel();
    _authSub?.cancel();
    _storedSub?.cancel();
    return super.close();
  }
}

/// Status of the deferred-navigation machine.
enum DeepLinkNavStatus {
  initial,
  idle,
  processing,
  navigationReady,
  awaitingAuthentication,
  navigationFailed,
  navigationSkippedUnauthenticated,
}

/// Sealed-style state: private `._()` ctor + a named constructor per status.
/// Equatable so the `BlocListener` `listenWhen` can compare cheaply.
class DeepLinkNavState extends Equatable {
  const DeepLinkNavState._({
    required this.status,
    this.deepLinkData,
    this.pendingDeepLink,
    this.isAuthenticated = false,
  });

  const DeepLinkNavState.initial() : this._(status: DeepLinkNavStatus.initial);

  const DeepLinkNavState.idle() : this._(status: DeepLinkNavStatus.idle);

  const DeepLinkNavState.processing(
    DeepLinkData data, {
    required bool isAuthenticated,
    DeepLinkData? pendingDeepLink,
  }) : this._(
          status: DeepLinkNavStatus.processing,
          deepLinkData: data,
          pendingDeepLink: pendingDeepLink,
          isAuthenticated: isAuthenticated,
        );

  const DeepLinkNavState.navigationReady(
    DeepLinkData data, {
    required bool isAuthenticated,
  }) : this._(
          status: DeepLinkNavStatus.navigationReady,
          deepLinkData: data,
          isAuthenticated: isAuthenticated,
        );

  const DeepLinkNavState.awaitingAuthentication(
    DeepLinkData data, {
    DeepLinkData? pendingDeepLink,
  }) : this._(
          status: DeepLinkNavStatus.awaitingAuthentication,
          deepLinkData: data,
          pendingDeepLink: pendingDeepLink,
        );

  final DeepLinkNavStatus status;
  final DeepLinkData? deepLinkData;
  final DeepLinkData? pendingDeepLink;
  final bool isAuthenticated;

  DeepLinkNavState copyWith({
    DeepLinkNavStatus? status,
    DeepLinkData? deepLinkData,
    DeepLinkData? pendingDeepLink,
    bool? isAuthenticated,
  }) {
    return DeepLinkNavState._(
      status: status ?? this.status,
      deepLinkData: deepLinkData ?? this.deepLinkData,
      pendingDeepLink: pendingDeepLink ?? this.pendingDeepLink,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, deepLinkData, pendingDeepLink, isAuthenticated];
}

// Concrete singleton clients. One per client family. Each resolves its `Url`
// from the injected Environment at call time and caches itself in a static
// field so the whole app shares one Dio (and therefore one HTTP/2 connection
// pool) per host.
//
// Rename anchors: `App` -> your app name only if you really want a brand prefix;
// otherwise leave as App. The RefreshTokenClient is deliberately a plain
// NonLoggedClient: it performs the refresh call WITHOUT auth interceptors, which
// is what breaks the refresh -> 401 -> refresh recursion.

import 'package:get_it/get_it.dart';

import 'package:app/gateway/abstract_gateway.dart';
import 'package:app/gateway/interceptor/refresh_token_interceptor.dart';
import 'package:app/gateway/interceptor/token_interceptor.dart';
import 'package:app/gateway/model/url.dart';
import 'package:app/main/environment.dart';

/// Authenticated singleton client. Repositories depend on `LoggedClient` (the
/// family) and receive this instance from the DI container.
class AppLoggedClient extends LoggedClient {
  AppLoggedClient._(this._token, this._refresh) : super();

  final TokenInterceptor _token;
  final RefreshTokenInterceptor _refresh;

  static AppLoggedClient? _instance;

  factory AppLoggedClient(TokenInterceptor token, RefreshTokenInterceptor refresh) =>
      _instance ??= AppLoggedClient._(token, refresh);

  @override
  Url get url => GetIt.instance.get<Environment>().serverUrl;

  @override
  bool get isEnableEncrypt => false;

  @override
  Interceptor? getTokenInterceptor() => _token;

  @override
  Interceptor? getRefreshTokenInterceptor() => _refresh;
}

/// Public singleton client for unauthenticated endpoints.
class AppNonLoggedClient extends NonLoggedClient {
  AppNonLoggedClient._() : super();

  static AppNonLoggedClient? _instance;

  factory AppNonLoggedClient() => _instance ??= AppNonLoggedClient._();

  @override
  Url get url => GetIt.instance.get<Environment>().serverUrl;

  @override
  bool get isEnableEncrypt => false;
}

/// Refresh-only client. A plain NonLoggedClient on purpose: it has NO token or
/// refresh interceptor, so the refresh request cannot itself trigger a refresh.
/// CheckUserAuth uses this to obtain a new access token.
class AppRefreshTokenClient extends NonLoggedClient {
  AppRefreshTokenClient._() : super();

  static AppRefreshTokenClient? _instance;

  factory AppRefreshTokenClient() => _instance ??= AppRefreshTokenClient._();

  @override
  Url get url => GetIt.instance.get<Environment>().serverUrl;

  @override
  bool get isEnableEncrypt => false;
}

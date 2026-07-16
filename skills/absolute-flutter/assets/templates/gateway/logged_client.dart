// Authenticated client family. This abstract layer only declares that a logged
// client supplies a token interceptor and a refresh interceptor; the base class
// (`abstract_gateway.dart`) already appends them in the correct order
// (refresh BEFORE token-inject). Concrete singletons live in `app_client.dart`.
//
// In a real project `LoggedClient` is usually declared directly in
// `abstract_gateway.dart` (as it is in that template). This file exists as a
// standalone copy target when a project keeps the client families in
// `service/client/` separate from the base gateway.

import 'package:dio/dio.dart';

import 'package:app/gateway/abstract_gateway.dart';
import 'package:app/gateway/interceptor/refresh_token_interceptor.dart';
import 'package:app/gateway/interceptor/token_interceptor.dart';

/// Marker family for endpoints that require a Bearer token. Subclasses wire the
/// concrete TokenInterceptor / RefreshTokenInterceptor instances.
abstract class LoggedClientBase extends LoggedClient {
  LoggedClientBase({super.isEnableEncrypt, super.apiKey});

  TokenInterceptor get tokenInterceptor;
  RefreshTokenInterceptor get refreshTokenInterceptor;

  @override
  Interceptor? getTokenInterceptor() => tokenInterceptor;

  @override
  Interceptor? getRefreshTokenInterceptor() => refreshTokenInterceptor;
}

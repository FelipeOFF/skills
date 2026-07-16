// Injects the Bearer access token on every outgoing authenticated request, and
// REJECTS the request with a synthetic 401 when the token is missing or expired.
// That synthetic 401 is what `DioException.asAppError()` later maps to `Logout`,
// so an expired token funnels cleanly to auto-logout without a network round
// trip. Token expiry is checked client-side from the JWT `exp` claim.

import 'package:dio/dio.dart';

import 'package:app/gateway/util/constants.dart';
import 'package:app/gateway/util/jwt_ext.dart';
import 'package:app/storage/token_store.dart';

class TokenInterceptor extends Interceptor {
  TokenInterceptor(this._store);

  final TokenStore _store;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final String? token = await _store.accessToken;
    final bool present = token != null && token.isNotEmpty;
    final bool expired = token?.isExpiredJwt ?? true;

    if (present && !expired) {
      options.headers[authorizationHeader] = 'Bearer $token';
      return handler.next(options);
    }

    // No usable token: reject with a synthetic 401 so the error funnel logs out.
    return handler.reject(
      DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
          statusMessage: 'Token expired',
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

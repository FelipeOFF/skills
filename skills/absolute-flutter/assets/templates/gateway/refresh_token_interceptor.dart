// Runs BEFORE the TokenInterceptor on every authenticated request. If the stored
// session looks unauthenticated, it refreshes the access token exactly once —
// guarded by a `synchronized` Lock so that a burst of concurrent 401s triggers
// ONE refresh, not a storm. The actual refresh call goes through a dedicated
// refresh-only client (no auth interceptors) to avoid infinite recursion.

import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

import 'package:app/gateway/util/check_user_auth.dart';
import 'package:app/model/api/common/error_dto.dart';
import 'package:app/model/api/common/response_dto.dart';
import 'package:app/storage/token_store.dart';

class RefreshTokenInterceptor extends Interceptor {
  RefreshTokenInterceptor(this._auth, this._store);

  final CheckUserAuth _auth;
  final TokenStore _store;
  final Lock _lock = Lock();

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await _lock.synchronized(() async {
      if (!await _auth.isSessionUnauthenticated()) {
        return handler.next(options);
      }
      if (!await _auth.hasUsableRefreshToken()) {
        return _logout(handler, options, 'No refresh token');
      }
      try {
        await _auth.refresh(); // hits the refresh-only client, persists new token
        return handler.next(options);
      } catch (error) {
        await _store.clear();
        return _logout(handler, options, error);
      }
    });
  }

  void _logout(RequestInterceptorHandler handler, RequestOptions options, Object error) {
    handler.reject(
      DioException(
        requestOptions: options,
        error: error,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
          statusMessage: 'Refresh invalid',
          data: const ResponseDto<dynamic>(status: 'refresh token', error: ErrorDto()),
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }
}

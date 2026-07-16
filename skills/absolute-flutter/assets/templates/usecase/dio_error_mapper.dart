import 'dart:io';

import 'package:dio/dio.dart';

import 'package:app/common/util/network_info.dart';
import 'package:app/domain/app_error.dart';

/// The SINGLE Dio -> domain translation point. Every transport error becomes a
/// typed [AppError] here, so no use case, repository, or controller ever
/// inspects a raw [DioException]. Classification order matters:
///
///   1. offline               -> [NetworkException]
///   2. 401 Unauthorized      -> [Logout]
///   3. parseable error body  -> [Default]
///   4. anything else         -> [UnknownException]
extension AsAppError on DioException {
  Future<AppError> asAppError() async {
    if (!await hasNetwork()) return const NetworkException();
    if (response?.statusCode == HttpStatus.unauthorized) return const Logout();

    final parsed = _tryParseErrorBody();
    if (parsed != null) {
      return Default(
        code: response?.statusCode,
        message: parsed.message,
        serverCode: parsed.code,
      );
    }
    return UnknownException(exception: error);
  }

  /// Best-effort parse of a `{ "code": ..., "message": ... }` error envelope.
  /// Returns null when the body is absent or not in the expected shape, so the
  /// caller falls through to [UnknownException].
  _ServerError? _tryParseErrorBody() {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      return _ServerError(
        code: data['code']?.toString(),
        message: data['message']?.toString(),
      );
    }
    return null;
  }
}

class _ServerError {
  final String? code;
  final String? message;

  const _ServerError({this.code, this.message});
}

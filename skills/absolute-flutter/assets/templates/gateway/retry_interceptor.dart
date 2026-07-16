// Connection retry with exponential backoff + jitter. Retries only transient,
// retryable failures (timeouts, socket/connection errors) and only up to a cap,
// tracked per request via a static attempt map keyed by method+uri+body hash.
// Retries are issued on a FRESH Dio().fetch(clonedOptions), never on the
// original instance (whose interceptor stack would re-run and re-trigger refresh).
//
// Call `cleanupRetryTracking()` periodically so the static map does not leak.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:app/gateway/util/constants.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxAttempts = 3});

  final int maxAttempts;

  /// Attempt counter shared across all requests. Keyed by a request signature so
  /// concurrent calls do not clobber each other's counts.
  static final Map<String, int> _attempts = <String, int>{};

  /// Drop stale counters. Call from app lifecycle (e.g. on resume) to avoid leaks.
  static void cleanupRetryTracking() => _attempts.clear();

  String _keyFor(RequestOptions options) =>
      '${options.method}:${options.uri}:${options.data.hashCode}';

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return error.error is SocketException || error.error is HttpException;
      default:
        return false;
    }
  }

  Duration _backoff(int attempt) {
    final int base = kRetryBaseDelayMs * (1 << (attempt - 1));
    final int jitter = Random().nextInt(kRetryJitterMs);
    return Duration(milliseconds: base + jitter);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final String key = _keyFor(err.requestOptions);
    final int attempt = (_attempts[key] ?? 0) + 1;

    if (!_isRetryable(err) || attempt > maxAttempts) {
      _attempts.remove(key);
      return handler.next(err);
    }

    _attempts[key] = attempt;
    await Future<void>.delayed(_backoff(attempt));

    try {
      final RequestOptions clone = err.requestOptions;
      final Response<dynamic> response = await Dio().fetch<dynamic>(clone);
      _attempts.remove(key);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return onError(retryError, handler);
    }
  }
}

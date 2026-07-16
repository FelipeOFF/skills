import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/domain/app_error.dart';
import 'package:app/domain/dio_error_mapper.dart';

/// Base contract for every single-shot use case.
///
/// Subclasses override ONLY [execute] with pure happy-path logic that returns a
/// [RESULT] (or throws freely). The base wraps that in [call], which is the
/// single try/catch + `Either` boundary in the whole domain layer: it converts
/// any throwable into a typed [AppError] on the `Left`, logs it, and routes the
/// optional [cache] hook. No subclass ever writes a try/catch or touches dartz.
abstract class AbstractUseCase<PARAM, RESULT> {
  const AbstractUseCase();

  /// Optional cache decorator. Default `null` = no caching for this use case.
  /// Override to return a cache keyed on [params]; [call] plumbs `forceRefresh`
  /// through automatically.
  CacheStore<RESULT>? cache(PARAM params) => null;

  /// Optional stable cache-key prefix. When null the param's `toString()` is
  /// used. Override for use cases whose params do not stringify uniquely.
  String? get key => null;

  /// The ONLY method a subclass implements. Pure happy path: call the
  /// repository / compose other use cases, return [RESULT], or throw. Never
  /// returns an `Either` and never catches transport errors.
  Future<RESULT> execute(PARAM param);

  /// Callable entry point: `useCase(param)` invokes this. Runs [execute] (via
  /// the optional [cache]), then wraps success in `Right` and any error in a
  /// typed `Left`. This is the single error funnel of the domain layer.
  Future<Either<AppError, RESULT>> call(PARAM params, {bool forceRefresh = false}) async {
    try {
      final cacheStore = cache(params);
      final RESULT result;
      if (cacheStore != null) {
        final cacheKey = key != null ? '${key}_$params' : params.toString();
        result = await cacheStore.get(cacheKey, () => execute(params), forceRefresh: forceRefresh);
      } else {
        result = await execute(params);
      }
      return Right(result);
    } on DioException catch (e, st) {
      logger.e(e, error: e, stackTrace: st);
      return Left(await e.asAppError());
    } catch (e, st) {
      logger.e(e, error: e, stackTrace: st);
      return Left(UnknownException(exception: e));
    }
  }
}

/// Minimal cache-store contract the base depends on. The concrete decorator
/// lives in the cache layer (see `07-cache-database.md`); this interface keeps
/// the domain layer from importing it directly.
abstract class CacheStore<T> {
  Future<T> get(String key, Future<T> Function() compute, {bool forceRefresh = false});
}

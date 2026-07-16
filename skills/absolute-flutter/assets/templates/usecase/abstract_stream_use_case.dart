import 'package:dartz/dartz.dart';

import 'package:app/common/util/logger.dart';
import 'package:app/domain/app_error.dart';

/// Stream twin of [AbstractUseCase]. Same contract, but [execute] yields a
/// `Stream<RESULT>` and [call] re-emits each event as `Right`, mapping any
/// error in the stream to a typed `Left`. Use for live/observable sources
/// (a query stream, a socket, a reactive cache) where a single `Future` does
/// not fit.
abstract class AbstractStreamUseCase<PARAM, RESULT> {
  const AbstractStreamUseCase();

  /// The ONLY method a subclass implements. Yields [RESULT] events or throws.
  /// Never yields an `Either`.
  Stream<RESULT> execute(PARAM param);

  /// Callable entry point: `useCase(param)` invokes this. Wraps each event in
  /// `Right`; on error emits a single `Left` and ends the stream.
  Stream<Either<AppError, RESULT>> call(PARAM params) async* {
    try {
      await for (final event in execute(params)) {
        yield Right(event);
      }
    } catch (e, st) {
      logger.e(e, error: e, stackTrace: st);
      yield Left(UnknownException(exception: e));
    }
  }
}

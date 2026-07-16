import 'package:dartz/dartz.dart';

/// Ergonomic accessors over dartz `Either`, so composing code reads
/// `result.unwrapRight` / `result.unwrapLeft` instead of a verbose `.fold`.
///
/// WARNING: [unwrapRight] returns `R?` — a legitimately-null success value is
/// indistinguishable from "was a Left". Always check `isLeft()` first when the
/// success type is nullable. The controller ladder (execSingle) does exactly
/// this; preserve that order if you read an `Either` by hand.
extension EitherHelpers<L, R> on Either<L, R> {
  /// The `Right` value, or null if this is a `Left`.
  R? get unwrapRight => toOption().toNullable();

  /// The `Left` value, or null if this is a `Right`.
  L? get unwrapLeft => swap().toOption().toNullable();
}

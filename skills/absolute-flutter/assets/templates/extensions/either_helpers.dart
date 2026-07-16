// lib/common/util/either_helpers.dart
//
// Ergonomic accessors over dartz `Either<L, R>`, so composing code reads
// `result.unwrapRight` / `result.onRight(...)` instead of a verbose `.fold`.
// This is the SAME file imported by BaseController (`execSingle` reads an
// `Either` exactly this way) — there is ONE either_helpers.dart per app, here
// under common/util/. Do not create a second copy in the extensions folder.
//
// WARNING: [unwrapRight] returns `R?` — a legitimately-null success value is
// indistinguishable from "was a Left". Check `isLeft()` first when `R` is
// nullable. The controller ladder does exactly this; preserve that order if you
// unwrap an `Either` by hand.
import 'package:dartz/dartz.dart';

extension EitherHelpers<L, R> on Either<L, R> {
  /// The `Right` value, or null if this is a `Left`.
  R? get unwrapRight => toOption().toNullable();

  /// The `Left` value, or null if this is a `Right`.
  L? get unwrapLeft => swap().toOption().toNullable();

  /// True when this holds a `Right`.
  bool get isRight => fold((_) => false, (_) => true);

  /// The `Right` value or [fallback] when this is a `Left`. Total (never null),
  /// unlike [unwrapRight].
  R getOrElse(R fallback) => fold((_) => fallback, (R r) => r);

  /// Runs [op] only on the `Right` branch and returns `this` unchanged, for
  /// side effects in a chain: `result.onRight(cache.write).onLeft(log)`.
  Either<L, R> onRight(void Function(R right) op) {
    fold((_) {}, op);
    return this;
  }

  /// Runs [op] only on the `Left` branch and returns `this` unchanged.
  Either<L, R> onLeft(void Function(L left) op) {
    fold(op, (_) {});
    return this;
  }
}

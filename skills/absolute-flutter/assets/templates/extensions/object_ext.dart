// lib/common/util/object_ext.dart
//
// Kotlin-style scope function (`let`) + null-safe cast, on the most general
// receiver. `let` runs a block with `this` as its argument and returns the
// block's result, so a value can be transformed inline without a local.
//
// `castOrNull` is DECLARED TWICE — once on `Object`, once on `dynamic` —
// because an `on Object` extension does NOT match a receiver statically typed
// `dynamic`. Keep both or `someDynamic.castOrNull<T>()` won't resolve. This is
// load-bearing duplication, not an oversight.
extension ObjectExt<T> on T {
  /// Runs [op] with `this` as `it` and returns its result. Enables inline
  /// transforms: `final id = rawId.let((it) => int.tryParse(it));`.
  R let<R>(R Function(T it) op) => op(this);
}

extension CastOrNullByObject on Object {
  /// Returns `this as T?` when the runtime type matches, else null — a cast
  /// that yields null instead of throwing.
  T? castOrNull<T>() => this is T ? this as T? : null;
}

extension CastOrNullByDynamic on dynamic {
  /// `dynamic` twin of [CastOrNullByObject.castOrNull]. Required because the
  /// `on Object` extension does not apply to a `dynamic`-typed receiver.
  T? castOrNull<T>() => this is T ? this as T? : null;
}

// lib/common/util/list_ext.dart
//
// Generic safe-access + fold helpers on Iterable<T>. Written once on the most
// general receiver (`Iterable<T>`) so every List/Set/Iterable inherits them.
// The null-safe accessors return `T?` instead of throwing RangeError — the
// canonical "return nullable, don't throw" pattern.
extension ListExt<T> on Iterable<T> {
  /// Element at [index] or null when out of range. Replaces `elementAt` for
  /// untrusted indices (avoids RangeError).
  T? safeElementAt(int index) =>
      index < 0 || index >= length ? null : elementAt(index);

  /// Alias of [safeElementAt] for call sites that read like map access.
  T? safeGet(int index) => safeElementAt(index);

  /// First element matching [test], or null when none match (non-throwing
  /// `firstWhere`).
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final T element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// Sums an int selector across the collection. Selector-based fold keeps the
  /// numeric reduction at the call site readable: `items.sumBy((e) => e.qty)`.
  int sumBy(int Function(T element) selector) =>
      fold(0, (int prev, T curr) => prev + selector(curr));

  /// `double` twin of [sumBy] for fractional accumulation.
  double sumByDouble(num Function(T element) selector) =>
      fold(0.0, (double prev, T curr) => prev + selector(curr));
}

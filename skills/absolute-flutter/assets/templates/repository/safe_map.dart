// lib/common/util/safe_map.dart
//
// Null-safe cast helpers wrapped around every `response.data` BEFORE fromJson.
// A null or malformed body becomes {} instead of throwing, so envelope decode
// never blows up on an empty/garbage payload. Used everywhere in repository
// impls: `safeMapOf(response.data)` and `e.asSafeMap` for list elements.

/// Coerces an arbitrary value to a `Map<String, dynamic>`. Returns an empty map
/// when the value is null or not a map.
Map<String, dynamic> safeMapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return <String, dynamic>{};
}

extension SafeMapExtension on Object? {
  /// `someValue.asSafeMap` — same coercion as [safeMapOf], as an extension for
  /// inline use inside list-element decoders.
  Map<String, dynamic> get asSafeMap => safeMapOf(this);
}

// lib/common/util/string_ext.dart
//
// Native-type utility extension on String. ONE type per file under common/util/.
// Pure helpers only: validation, formatting, null-safe parsing. No side effects,
// no BuildContext. No-arg, pure helpers are `get`; anything taking an argument is
// a method. `this` is implicit for member access (`trim()`, `substring(...)`) and
// explicit only in interpolation (`'$this'`).
import 'dart:convert';

extension StringExt on String {
  /// True when this is empty after trimming (treats whitespace-only as blank).
  bool get isBlankOrNull => trim().isEmpty;

  /// True when this string contains at least one upper-case letter.
  bool get hasUpperCase => contains(RegExp('[A-Z]'));

  /// Title-cases the first char and lower-cases the rest. Guards empty input.
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';

  /// Decodes a JSON object string into a map; empty string yields `{}` instead
  /// of throwing.
  Map<String, dynamic> get toJsonMap =>
      isNotEmpty ? jsonDecode(this) as Map<String, dynamic> : <String, dynamic>{};

  /// Truncates to [maxLength] with an ellipsis when longer; returns `this`
  /// unchanged when it already fits. Method (takes an arg), not a getter.
  String ellipsize(int maxLength) =>
      length > maxLength ? '${substring(0, maxLength - 1)}…' : this;

  /// A named rule-set as a map of booleans, used to drive a UI validity
  /// checklist (one row per key). Keep the keys stable — the View reads them.
  Map<String, bool> get passwordRules => <String, bool>{
        'noSpace': !contains(' '),
        'notEmpty': isNotEmpty,
        'minLen': length >= 4,
        'maxLen': length <= 16,
      };
}

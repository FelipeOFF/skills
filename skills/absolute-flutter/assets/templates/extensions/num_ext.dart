// lib/common/util/num_ext.dart
//
// Locale-aware number formatting on `num` (the workhorse). Methods, not getters
// — every entry point needs a `Locale`, so formatting is parameterised. `this`
// is EXPLICIT in arithmetic and interpolation (`this / 1000`, `'$suffix'`);
// forgetting it is the classic slip in number extensions.
//
// Not everything must be an extension: a free module-level helper
// (`currencySymbolFor`) lives alongside when there is no natural receiver.
import 'dart:ui';

import 'package:intl/intl.dart';

extension FormatterX on num {
  NumberFormat _format(
    Locale locale, {
    int? maxFractionDigits,
    int? minFractionDigits,
  }) {
    final NumberFormat f = NumberFormat.decimalPattern(locale.toLanguageTag());
    if (maxFractionDigits != null) f.maximumFractionDigits = maxFractionDigits;
    if (minFractionDigits != null) f.minimumFractionDigits = minFractionDigits;
    return f;
  }

  /// Whole-number grouped format for the given [locale] (no fraction digits).
  String format(Locale locale) =>
      _format(locale, maxFractionDigits: 0, minFractionDigits: 0).format(this);

  /// Fixed-fraction grouped format with exactly [fractionDigits] decimals.
  String formatFixed(int fractionDigits, Locale locale) => _format(
        locale,
        maxFractionDigits: fractionDigits,
        minFractionDigits: fractionDigits,
      ).format(this);

  /// Compact "power" notation: 12k, 3.4M, 1B. Drops the decimal on round
  /// thousands. Negative values keep their sign via the underlying format.
  String formatCompact(Locale locale) {
    final num magnitude = abs();
    if (magnitude < 1000) return format(locale);
    if (magnitude < 1000000) {
      return '${(this / 1000).formatFixed(magnitude % 1000 == 0 ? 0 : 1, locale)}k';
    }
    if (magnitude < 1000000000) {
      return '${(this / 1000000).formatFixed(magnitude % 1000000 == 0 ? 0 : 1, locale)}M';
    }
    return '${(this / 1000000000).formatFixed(magnitude % 1000000000 == 0 ? 0 : 1, locale)}B';
  }
}

/// Module-level helper alongside the extension — there is no `num` receiver to
/// hang a currency symbol on, so it stays a plain function.
String currencySymbolFor(String currencyCode) =>
    NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

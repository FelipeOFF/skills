// lib/feature/example/view/localization_usage_example.dart
//
// Demonstrates the two access paths for localized strings:
//   - IN A WIDGET: `context.s.<key>` (the shortcut from
//     localization_context_ext.dart) — needs a BuildContext.
//   - IN NON-WIDGET CODE (data source, service, mapper): `AppLocalizations.current.<key>`
//     — the static accessor that reads the last-loaded locale, no context needed.
//
// Placeholders are generated as METHOD parameters:
//   greeting({name})       -> context.s.greeting('Alex')
//   itemsCount({count})    -> context.s.itemsCount(3)   // ICU plural
//
// AppLocalizations is the intl_utils-generated class (see 14-i18n.md). Import it
// from package:app/generated/l10n.dart.
import 'package:flutter/material.dart';

import 'package:app/common/util/localization_context_ext.dart';
import 'package:app/generated/l10n.dart';

/// A widget reading localized strings through the `context.s` shortcut.
class LocalizationUsageExample extends StatelessWidget {
  const LocalizationUsageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Plain key.
        Text(context.s.welcomeTitle),
        // String placeholder -> positional method argument.
        Text(context.s.greeting('Alex')),
        // ICU plural -> the int drives =0 / =1 / other.
        Text(context.s.itemsCount(3)),
      ],
    );
  }
}

/// Non-widget code (e.g. a data source) has no BuildContext, so it reads the
/// CURRENT locale's strings statically. `AppLocalizations.current` is the
/// last-loaded instance; it is valid after the first `load(...)` (which the
/// delegate performs during MaterialApp setup).
class ExampleDataSource {
  /// Returns a localized fallback label without any context.
  String genericConfirmLabel() => AppLocalizations.current.ok;
}

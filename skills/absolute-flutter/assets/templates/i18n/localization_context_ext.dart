// lib/common/util/localization_context_ext.dart
//
// The `context.s` shortcut for localized strings. A widget writes
// `context.s.welcomeTitle` instead of `AppLocalizations.of(context).welcomeTitle`
// — shorter and greppable, and the SINGLE sanctioned way widgets reach l10n.
//
// AppLocalizations is the intl_utils-generated class (class_name: AppLocalizations
// in the flutter_intl pubspec block). Its `of(context)` is non-null and asserts a
// delegate is installed, so `context.s` never returns null. See 14-i18n.md.
//
// NAME COLLISION: the design-system spacing extension ALSO exposes `context.s`
// (AppSpacingTheme, `context.s.md`). Two `s` getters on BuildContext are
// ambiguous if both files are imported into the SAME library — Dart raises
// "the property 's' is defined in multiple extensions". Pick ONE per file, or
// disambiguate with explicit extension-override syntax
// (`LocalizationContextExt(context).s`). See the gotchas in 14-i18n.md.
import 'package:flutter/widgets.dart';

import 'package:app/generated/l10n.dart';

extension LocalizationContextExt on BuildContext {
  /// Localized strings for the current locale — `context.s.welcomeTitle`.
  /// Delegates to the generated `AppLocalizations.of(this)` (non-null, asserts
  /// the delegate is registered in MaterialApp.localizationsDelegates).
  AppLocalizations get s => AppLocalizations.of(this);
}

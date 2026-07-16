// lib/app_widget.dart  (localization-aware variant)
//
// The root widget, wired for i18n + runtime locale switching. It is a
// StatefulWidget (not the stateless app_scaffold/app_widget.dart) BECAUSE the
// active Locale is mutable state owned here: switching language = setState a new
// Locale and let MaterialApp rebuild.
//
// Three i18n responsibilities:
//   1. localizationsDelegates: AppLocalizations.delegate (the generated one) +
//      the three Global*Localizations delegates (Material/Widgets/Cupertino) so
//      framework strings + text direction localize too.
//   2. supportedLocales: AppLocalizations.delegate.supportedLocales — derived
//      from the .arb files, never hand-listed.
//   3. locale: _locale — null lets the device locale win; a non-null value
//      forces it (the runtime-switch path).
//
// AppLocalizations is the intl_utils-generated class (package:app/generated/l10n.dart,
// class_name: AppLocalizations). AppRouter.config is the go_router instance (see
// 11-navigation.md). LocaleChangeService is resolved from DI (see 03-di.md).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:app/common/service/locale_change_service.dart';
import 'package:app/di/app_di.dart';
import 'package:app/generated/l10n.dart';
import 'package:app/navigation/app_router.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  /// Active locale. `null` -> follow the device locale (resolved against
  /// supportedLocales). A non-null value is the runtime override set by a
  /// notifyLocaleChanged(...) call.
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    // Register the rebuild closure on the singleton service. Any caller that
    // resolves LocaleChangeService and calls notifyLocaleChanged(locale) lands
    // here and rebuilds MaterialApp with the new locale.
    AppDI.it<LocaleChangeService>().setListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppDI.it<LocaleChangeService>().clearListener();
    super.dispose();
  }

  void _onLocaleChanged(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // 1. Delegates: the generated app delegate FIRST, then the three framework
      //    delegates so Material/Cupertino widgets and text direction localize.
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 2. Supported locales are DERIVED from the .arb files — never hand-listed.
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      // 3. null -> device locale; non-null -> runtime override.
      locale: _locale,
      routerConfig: AppRouter.config,
    );
  }
}

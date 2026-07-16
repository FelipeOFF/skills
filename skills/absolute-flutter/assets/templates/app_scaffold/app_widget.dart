// lib/app_widget.dart
//
// The root widget. It does exactly three things:
//   1. builds the ThemeData and attaches the app's ThemeExtension token
//      palettes (colors / text / icons) so any widget can read them via the
//      BuildContext extensions defined in design_system/,
//   2. wires go_router through MaterialApp.router (routerConfig),
//   3. nothing else — no business logic, no DI, no state. Features own that.
//
// AppRouter.config is the go_router instance built from the route enum table
// (see navigation/ and reference 11-navigation.md). AppColors / AppText are the
// ThemeExtensions (see design_system/ and reference 09-design-system.md). Both
// are rename anchors: a generator may swap in the real names.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:app/design_system/theme/app_colors.dart';
import 'package:app/design_system/theme/app_text.dart';
import 'package:app/generated/l10n.dart';
import 'package:app/navigation/app_router.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      // i18n: the generated AppLocalizations delegate + the three framework
      // delegates so Material/Cupertino widgets and text direction localize too.
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Derived from the .arb files — never hand-listed. This stateless variant
      // follows the device locale only. For runtime locale switching (a mutable
      // Locale + LocaleChangeService), see references/14-i18n.md.
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      routerConfig: AppRouter.config,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      // Token palettes live in ThemeExtensions so widgets read design tokens via
      // context.colors / context.text instead of hard-coded values.
      extensions: const <ThemeExtension<dynamic>>[
        AppColors.light,
        AppText.standard,
      ],
    );
  }
}

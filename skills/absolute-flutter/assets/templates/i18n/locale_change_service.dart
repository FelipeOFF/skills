// lib/common/service/locale_change_service.dart
//
// Runtime locale switching without an inherited-widget rebuild storm. The root
// App state owns the active Locale; this service is the one-way channel that lets
// ANYTHING (a settings Controller, a deep link, a remote-config push) ask the
// root to rebuild with a new locale, without holding a BuildContext.
//
// HOW IT WIRES (see app_localization_wiring.dart + 03-di.md):
//   1. Register ONE instance as a get_it singleton:
//        it.registerLazySingleton<LocaleChangeService>(LocaleChangeService.new);
//   2. The root App state, in initState, sets `_onLocaleChanged` to a closure
//      that calls setState with the new Locale.
//   3. Any caller resolves the singleton and calls `notifyLocaleChanged(locale)`;
//      the root rebuilds MaterialApp with `locale: newLocale`.
//
// This is a deliberately tiny callback holder — no streams, no state notifier —
// because there is exactly one consumer (the root) and one signal.
import 'dart:ui' show Locale;

class LocaleChangeService {
  /// Set by the root App state. `null` until the App mounts (a notification
  /// before then is simply dropped, which is the desired pre-runApp behavior).
  void Function(Locale locale)? _onLocaleChanged;

  /// Called once by the root App state in `initState`. Wiring a second listener
  /// would silently replace the first, so there is exactly ONE registrant.
  void setListener(void Function(Locale locale) listener) {
    _onLocaleChanged = listener;
  }

  /// Clears the listener when the root App state disposes, to avoid calling into
  /// a defunct State after a hot restart / teardown.
  void clearListener() {
    _onLocaleChanged = null;
  }

  /// Request a locale switch. The root App rebuilds MaterialApp with this locale.
  /// No-op if the App has not mounted yet.
  void notifyLocaleChanged(Locale locale) {
    _onLocaleChanged?.call(locale);
  }
}

// lib/main.dart
//
// Entry point. The ONLY job of main() is to bootstrap, in order:
//   1. bind the Flutter engine,
//   2. wire dependency injection (DI) BEFORE any widget can resolve a service,
//   3. run app-wide pre-runApp setup (env, orientation, error hooks),
//   4. runApp(const AppWidget()).
//
// Nothing builds UI before setupDI() completes — the first frame may resolve a
// Controller from get_it, and a Controller resolves use cases / repositories,
// so the container must be fully populated first. Keep this file tiny; all
// wiring lives in di/app_di.dart and the AbstractBinding list it iterates.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app/app_widget.dart';
import 'package:app/di/app_di.dart';

Future<void> main() async {
  // 1. Bind the engine before touching platform channels (DI, orientation).
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Populate the get_it container in dependency order (env → db → gateway →
  //    service → repository → domain → features). See AppDI.setupDI().
  await AppDI.setupDI();

  // 3. App-wide pre-runApp setup. Resolve infra from DI now that it exists.
  await _preRunSetup();

  // 4. Hand control to the widget tree.
  runApp(const AppWidget());
}

Future<void> _preRunSetup() async {
  // Lock orientation, install global error handlers, warm caches, etc.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // Route framework errors through the same logging path the app uses.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
}

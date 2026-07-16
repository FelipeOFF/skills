// lib/di/database/database_binding.dart
//
// DI wiring for the persistence layer. Two registration kinds, chosen by need:
//   - secure storage: registerSingleton — the impl has a `const` ctor and needs
//     no async setup, so it is available immediately.
//   - the Database: registerSingletonAsync — `DatabaseFactory.create()` awaits
//     `init()` (drift opens connections), so consumers resolve it via
//     `it.getAsync<Database>()`, never the sync `it<Database>()`.
//
// This binding belongs in DI phase 1 (infrastructure), before any repository or
// feature that reads from the cache. See `03-di.md` for the ordered bootstrap.
//
// Rename anchor: none — shared infrastructure, copy ONCE per app.
import 'package:get_it/get_it.dart';

import 'package:app/database/abstract_database.dart';
import 'package:app/database/secure_storage.dart';
import 'package:app/di/abstract_binding.dart';

class DatabaseBinding extends AbstractBinding {
  const DatabaseBinding();

  @override
  Future<void> binding(GetIt it) async {
    // Sync: const impl, no async setup. Available immediately.
    it.registerSingleton<AbstractFlutterSecureStorage>(const FlutterSecureStorageImpl());

    // Async: DatabaseFactory.create() awaits init() (drift opens connections).
    // Consumers resolve with `await it.getAsync<Database>()`.
    it.registerSingletonAsync<AbstractDatabase>(() => DatabaseFactory.instance.create());
  }
}

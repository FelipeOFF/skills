// lib/database/abstract_database.dart
//
// Engine-agnostic local-persistence facade. ONE interface over a swappable KV
// engine (drift today; sqflite/memory are stubbed seams). Two namespaces share
// the same shape: a *Persistent* store (durable, carries updatedAt) and a
// *NonPersistent* cache store (TTL-aware, carries expiresAt). All typing + JSON
// lives here; the engine below only moves raw `String` rows.
//
// Rename anchors: none — this file is shared infrastructure, copy it ONCE per
// app. `Database` is a typedef alias so callers depend on the interface, never
// the concrete engine.
import 'dart:async';

import 'package:app/database/drift/app_database.dart';

/// The KV facade every caller depends on. Resolve it from DI as `Database`.
abstract class AbstractDatabase {
  /// Open the underlying engine. Idempotent: a second call is a no-op. Every
  /// other method assumes [init] has completed (DI awaits it before exposing
  /// the instance).
  Future<void> init();

  // --- persistent namespace (durable, no TTL) -------------------------------

  /// JSON-decode the value at [key] as [T], or `null` if absent.
  Future<T?> readPersistent<T>(String key);

  /// JSON-encode [value] and store it durably. `String` values pass through
  /// un-encoded (the engine short-circuits when `T == String`).
  Future<void> writePersistent(String key, dynamic value);

  Future<void> deletePersistent(String key);

  // --- cache namespace (TTL-aware) ------------------------------------------

  /// JSON-decode the cache value at [key]. Returns `null` if absent OR expired
  /// (the engine purges expired rows lazily on read).
  Future<T?> readNonPersistent<T>(String key);

  /// Store [value] in the cache store with an optional [ttl]. When [ttl] is
  /// null the row never expires by time.
  Future<void> writeNonPersistent(String key, dynamic value, {Duration? ttl});

  Future<void> deleteNonPersistent(String key);

  // --- query / reactive ------------------------------------------------------

  /// Wildcard key lookup (`*` / `?`). Loads keys then filters in Dart — O(n),
  /// intended for small KV stores, not large tables.
  Future<List<String>> findKeys(String pattern, {bool persistent = false});

  /// Reactive read: emits on every change to [key]. Expired cache rows surface
  /// as `null` and are purged.
  Stream<T?> watchKey<T>(String key, {bool persistent = false});

  /// Close engine connections. Safe to call once at app teardown.
  Future<void> close();
}

/// Typedef alias. Callers and DI use `Database`, never the concrete engine —
/// drops any singleton wrapper and keeps the swap a one-line config change.
typedef Database = AbstractDatabase;

/// The storage engines the factory can build. `drift` is the only implemented
/// one; the others are deliberate seams (see [DatabaseFactory]).
enum DatabaseProvider { drift, sqflite, memory }

/// Static config for the persistence layer. The provider is a `const` so the
/// engine is chosen at build time, not wired into callers.
class DatabaseConfig {
  const DatabaseConfig._();

  static const DatabaseProvider provider = DatabaseProvider.drift;
  static const bool enableLogging = false;
}

/// Builds the configured [AbstractDatabase]. Singleton so the engine is created
/// once. The unimplemented branches prove the seam without paying for engines
/// the app does not use.
class DatabaseFactory {
  DatabaseFactory._internal();

  static final DatabaseFactory instance = DatabaseFactory._internal();

  Future<AbstractDatabase> create() => _build(DatabaseConfig.provider);

  Future<AbstractDatabase> _build(DatabaseProvider provider) async {
    switch (provider) {
      case DatabaseProvider.drift:
        final AbstractDatabase db = DriftDatabase();
        await db.init();
        return db;
      case DatabaseProvider.sqflite:
        throw UnimplementedError('sqflite engine not yet implemented');
      case DatabaseProvider.memory:
        throw UnimplementedError('memory engine not yet implemented');
    }
  }
}

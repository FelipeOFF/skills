// lib/database/drift/app_database.dart
//
// The drift engine: two drift databases (one table each) behind one
// AbstractDatabase. Persistent vs cache differ only by table + TTL handling.
// TTL is enforced at the ENGINE — expired cache rows are purged lazily on
// read / watch — so stale data never leaks even if an app-level check is
// bypassed. drift sees only raw `String` KV; all typing + JSON + validation
// live in `DriftDatabase` below.
//
// `part 'app_database.g.dart';` is build_runner output: run
//   dart run build_runner build --delete-conflicting-outputs
// to generate the `$CacheDatabase` / `$PersistentDatabase` superclasses. The
// generated file is committed and never hand-edited.
//
// Rename anchor: none structural — copy ONCE per app. `Example*Table` names
// follow the table file (`example_table.dart`).
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:app/database/abstract_database.dart';
import 'package:app/database/drift/example_table.dart';

part 'app_database.g.dart';

/// Top-level DB file names. Two files = a hard split between durable data and
/// disposable cache; clearing the cache never risks the persistent store.
const String _persistentDatabaseName = 'app_persistent';
const String _cacheDatabaseName = 'app_cache';

/// Hard limits, validated on every write. Centralized so one constant governs
/// the whole layer.
class DatabaseLimits {
  const DatabaseLimits._();

  static const int maxKeyLength = 512;
  static const int maxValueBytes = 1024 * 1024; // 1 MiB
}

// ---------------------------------------------------------------------------
// Cache drift DB (TTL). One table, raw String rows, lazy expiry purge.
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [ExampleCacheTable])
class CacheDatabase extends $CacheDatabase {
  CacheDatabase() : super(_open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
        name: _cacheDatabaseName,
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      );

  Future<String?> getValue(String key) async {
    final row = await (select(exampleCacheTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    if (_isExpired(row.expiresAt)) {
      await deleteValue(key); // lazy purge on read
      return null;
    }
    return row.value;
  }

  Future<void> setValue(String key, String value, {Duration? ttl}) async {
    final DateTime? expiresAt = ttl == null ? null : DateTime.now().add(ttl);
    await into(exampleCacheTable).insertOnConflictUpdate(
      ExampleCacheTableCompanion(
        key: Value(key),
        value: Value(value),
        expiresAt: Value(expiresAt),
      ),
    );
  }

  Future<void> deleteValue(String key) async {
    await (delete(exampleCacheTable)..where((t) => t.key.equals(key))).go();
  }

  Future<void> clearExpired() async {
    await (delete(exampleCacheTable)
          ..where((t) => t.expiresAt.isNotNull() & t.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();
  }

  Stream<String?> watchValue(String key) {
    return (select(exampleCacheTable)..where((t) => t.key.equals(key))).watchSingleOrNull().map((row) {
      if (row == null) return null;
      if (_isExpired(row.expiresAt)) {
        unawaited(deleteValue(key)); // fire-and-forget; keeps the stream reactive
        return null;
      }
      return row.value;
    });
  }

  static bool _isExpired(DateTime? expiresAt) => expiresAt != null && expiresAt.isBefore(DateTime.now());
}

// ---------------------------------------------------------------------------
// Persistent drift DB (durable). Mirrors the cache DB without any TTL.
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [ExamplePersistentTable])
class PersistentDatabase extends $PersistentDatabase {
  PersistentDatabase() : super(_open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
        name: _persistentDatabaseName,
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      );

  Future<String?> getValue(String key) async {
    final row = await (select(examplePersistentTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) async {
    await into(examplePersistentTable).insertOnConflictUpdate(
      ExamplePersistentTableCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteValue(String key) async {
    await (delete(examplePersistentTable)..where((t) => t.key.equals(key))).go();
  }

  Stream<String?> watchValue(String key) {
    return (select(examplePersistentTable)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<List<String>> allKeys() async {
    final rows = await select(examplePersistentTable).get();
    return rows.map((r) => r.key).toList();
  }
}

// ---------------------------------------------------------------------------
// Engine: typed JSON codec + validation over the two drift DBs.
// ---------------------------------------------------------------------------

class DriftDatabase implements AbstractDatabase {
  CacheDatabase? _cacheDb;
  PersistentDatabase? _persistentDb;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _cacheDb = CacheDatabase();
    _persistentDb = PersistentDatabase();
    _initialized = true;
  }

  @override
  Future<T?> readPersistent<T>(String key) async {
    _validateKey(key);
    final raw = await _persistent.getValue(key);
    return raw == null ? null : _decode<T>(raw);
  }

  @override
  Future<void> writePersistent(String key, dynamic value) async {
    _validateKey(key);
    final encoded = _encode(value);
    _validateValueSize(encoded);
    await _persistent.setValue(key, encoded);
  }

  @override
  Future<void> deletePersistent(String key) async {
    _validateKey(key);
    await _persistent.deleteValue(key);
  }

  @override
  Future<T?> readNonPersistent<T>(String key) async {
    _validateKey(key);
    final raw = await _cache.getValue(key);
    return raw == null ? null : _decode<T>(raw);
  }

  @override
  Future<void> writeNonPersistent(String key, dynamic value, {Duration? ttl}) async {
    _validateKey(key);
    final encoded = _encode(value);
    _validateValueSize(encoded);
    await _cache.setValue(key, encoded, ttl: ttl);
  }

  @override
  Future<void> deleteNonPersistent(String key) async {
    _validateKey(key);
    await _cache.deleteValue(key);
  }

  @override
  Future<List<String>> findKeys(String pattern, {bool persistent = false}) async {
    final regex = RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$');
    final keys = persistent ? await _persistent.allKeys() : <String>[];
    return keys.where(regex.hasMatch).toList();
  }

  @override
  Stream<T?> watchKey<T>(String key, {bool persistent = false}) {
    _validateKey(key);
    final raw$ = persistent ? _persistent.watchValue(key) : _cache.watchValue(key);
    return raw$.map((raw) => raw == null ? null : _decode<T>(raw));
  }

  @override
  Future<void> close() async {
    await _cacheDb?.close();
    await _persistentDb?.close();
    _initialized = false;
  }

  // --- codec ----------------------------------------------------------------

  /// `String` passes through; everything else is JSON-encoded.
  String _encode(dynamic value) => value is String ? value : jsonEncode(value);

  /// Returns the raw string when `T == String`; otherwise JSON-decodes and
  /// blind-casts. A wrong-shaped Map/List surfaces as a cast error upstream.
  T? _decode<T>(String raw) {
    if (T == String) return raw as T;
    return jsonDecode(raw) as T?;
  }

  // --- validation -----------------------------------------------------------

  void _validateKey(String key) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', 'must not be empty');
    if (key.length > DatabaseLimits.maxKeyLength) {
      throw ArgumentError.value(key, 'key', 'exceeds ${DatabaseLimits.maxKeyLength} chars');
    }
  }

  void _validateValueSize(String encoded) {
    if (encoded.length > DatabaseLimits.maxValueBytes) {
      throw ArgumentError.value(encoded.length, 'value', 'exceeds ${DatabaseLimits.maxValueBytes} bytes');
    }
  }

  CacheDatabase get _cache {
    final db = _cacheDb;
    if (db == null) throw StateError('DriftDatabase used before init()');
    return db;
  }

  PersistentDatabase get _persistent {
    final db = _persistentDb;
    if (db == null) throw StateError('DriftDatabase used before init()');
    return db;
  }
}

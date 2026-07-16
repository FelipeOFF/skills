// lib/database/drift/example_table.dart
//
// Raw key/value drift table. `value` is ALWAYS stored as TEXT — every typed
// value is JSON-encoded one layer up (in the engine codec), so this schema is
// domain-independent and `schemaVersion` never changes for new value types.
//
// Two tables share this shape. Rename the anchor `Example` to the namespace:
//   - the cache table keeps `expiresAt` (TTL) as below;
//   - the persistent table swaps `expiresAt` for a non-nullable `updatedAt`
//     and drops the TTL column entirely.
import 'package:drift/drift.dart';

/// Cache namespace table: `key` PK, `value` TEXT, plus a nullable [expiresAt]
/// that drives lazy TTL purging in `app_database.dart`.
@DataClassName('ExampleCacheRow')
class ExampleCacheTable extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Null = no time-based expiry. Set = the row is purged on the first read /
  /// watch after this instant.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Persistent namespace table: same KV shape, but durable. Carries a non-null
/// [updatedAt] (last-write timestamp) instead of a TTL — persistent rows never
/// expire by time.
@DataClassName('ExamplePersistentRow')
class ExamplePersistentTable extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

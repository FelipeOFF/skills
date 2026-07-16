// lib/cache/cache.dart
//
// The cache decorator chain, top to bottom:
//   Cache<T>            — typed save/get/delete contract (serialization only).
//   FuCache<T>          — read-through (cache-aside) policy in ONE place. It is
//                         the concrete `CacheStore<T>` the use-case base depends
//                         on, so opting a use case into caching is one override.
//   DriftDatabaseCache  — Cache<T> over AbstractDatabase, delegating TTL to the
//                         engine (`writeNonPersistent(ttl:)`) — engine-TTL, NOT
//                         a sidecar timestamp. Prefer this for new code.
//
// Rename anchors: `Example` -> the cached entity; `ExampleCacheKeys.x.name`
// supplies the key. The `CacheKey` enum keeps call sites string-literal-free.
import 'package:app/database/abstract_database.dart';
import 'package:app/domain/abstract_use_case.dart';
import 'package:app/environment/environment.dart';

/// (De)serialization strategy a [Cache] uses to bridge `T` and JSON. `toJson`
/// produces a `Map`/`List`/primitive the engine can encode; `fromJson` rebuilds
/// `T` from the decoded structure. For a Freezed DTO these are just the
/// generated `toJson` / `fromJson`.
abstract class AbstractCacheJsonParser<T> {
  const AbstractCacheJsonParser();

  dynamic toJson(T value);

  T fromJson(dynamic json);
}

/// Typed cache contract. Concrete impls ONLY serialize/deserialize and gate on
/// the [Environment] kill-switch — they do NOT decide when to refetch (that is
/// [FuCache]'s job).
abstract class Cache<T> {
  Future<T?> save(String key, T? value);

  Future<T?> get(String key);

  Future<void> delete(String key);
}

/// Read-through (cache-aside) wrapper and the app's single caching policy.
///
/// Implements [CacheStore] (the contract the use-case base calls) so a use case
/// enables caching by returning a `FuCache` from its `cache()` override — no
/// branching at call sites. `get`: return the cached hit unless [forceRefresh],
/// else run [compute], save it, return it.
class FuCache<T> implements CacheStore<T> {
  final Cache<T> _cache;

  const FuCache(this._cache);

  @override
  Future<T> get(String key, Future<T> Function() compute, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final hit = await _cache.get(key);
      if (hit != null) return hit;
    }
    final fresh = await compute();
    await _cache.save(key, fresh);
    return fresh;
  }

  Future<void> delete(String key) => _cache.delete(key);
}

/// `Cache<T>` backed by [AbstractDatabase]'s cache namespace, with TTL delegated
/// to the engine. Serializes via [jsonParse] when present; gates every op on
/// `environment.isEnableCache` so the cache is globally disable-able without
/// touching call sites.
class DriftDatabaseCache<T> implements Cache<T> {
  final Database _database;
  final Environment _environment;
  final AbstractCacheJsonParser<T>? jsonParse;
  final Duration lifeTime;

  const DriftDatabaseCache(
    this._database, {
    required Environment environment,
    this.jsonParse,
    this.lifeTime = const Duration(hours: 1),
  }) : _environment = environment;

  @override
  Future<T?> save(String key, T? value) async {
    if (!_environment.isEnableCache || value == null) return null;
    final dynamic body = jsonParse?.toJson(value) ?? value;
    await _database.writeNonPersistent(key, body, ttl: lifeTime); // engine owns TTL
    return value;
  }

  @override
  Future<T?> get(String key) async {
    if (!_environment.isEnableCache) return null;
    final raw = await _database.readNonPersistent<dynamic>(key);
    if (raw == null) return null;
    final parser = jsonParse;
    if (parser != null && (raw is Map || raw is List)) {
      return parser.fromJson(raw);
    }
    return raw as T?;
  }

  @override
  Future<void> delete(String key) => _database.deleteNonPersistent(key);
}

/// Cache keys as an enum, referenced as `ExampleCacheKeys.x.name` at call sites
/// — never a string literal. Add one value per cached query.
enum ExampleCacheKeys { findExampleById, listExamples }

# 07 — Cache & local persistence: drift split + FuCache cache-aside + secure storage

The local-persistence stack. One `AbstractDatabase` facade over a swappable
engine (drift), split into a **persistent** store and a **cache (TTL)** store; a
typed `Cache<T>` decorator chain with `FuCache<T>` owning the cache-aside policy;
and `flutter_secure_storage` for secrets on a parallel path. Caching plugs into a
use case through the `cache()` hook on `AbstractUseCase` — one override, no
branching at call sites.

Read `_conventions.md` first; it is the binding contract this doc obeys.

## When to use

Reach for this reference when the task is any of:

- Stand up the persistence layer for a new app (the facade, the drift engine,
  the secure-storage path, the DI binding).
- Cache a use case's result with a TTL (the common case — one `cache()` + one
  `key` override on the use case).
- Persist a value durably across launches (settings, a flag) via the persistent
  namespace.
- Store a secret (token, key) — that goes through secure storage, **never** the
  drift store.
- Add a new drift table column or bump the schema (rare — the KV schema is
  domain-independent).

It pairs with `04-usecases.md` (the use-case base owns the `cache()`/`key` hook
and the `CacheStore<T>` contract this layer satisfies) and `03-di.md` (the
two-phase ordered bootstrap this binding slots into, phase 1). Read those only as
you reach that part of the work.

## Pattern (the why)

Layers, top to bottom:

1. **`Cache<T>`** — typed `save`/`get`/`delete`. Concrete impls do ONLY
   serialization and gate on the `Environment` kill-switch. They do not decide
   *when* to refetch.
2. **`FuCache<T>`** — the cache-aside (read-through) policy in ONE place:
   return the cached hit unless `forceRefresh`, else run the producer, save,
   return. It implements `CacheStore<T>` — the exact contract the use-case base
   calls — so enabling caching is returning a `FuCache` from `cache()`.
3. **`DriftDatabaseCache<T>`** — a `Cache<T>` over `AbstractDatabase`'s cache
   namespace. TTL is delegated to the **engine** (`writeNonPersistent(ttl:)`),
   not tracked as a sidecar timestamp in app code. This is the preferred cache
   impl for new code.
4. **`AbstractDatabase`** — engine-agnostic KV facade with two namespaces:
   **persistent** (`*Persistent`, durable, carries `updatedAt`) and
   **non-persistent / cache** (`*NonPersistent`, TTL-aware, carries `expiresAt`).
   `Database` is a `typedef` alias — callers depend on the interface, never the
   engine.
5. **Engine** — `DriftDatabase implements AbstractDatabase`. Delegates to two
   drift databases (`CacheDatabase`, `PersistentDatabase`), one table each.
   Typed JSON codec, key/value validation, and lazy TTL purge live here; drift
   moves only raw `String` rows.
6. **`flutter_secure_storage`** — a SEPARATE path for secrets behind
   `AbstractFlutterSecureStorage` (Keychain / Keystore). Not part of
   `AbstractDatabase`.

WHY this shape:

- **Engine swappability.** `DatabaseFactory` + a `DatabaseProvider` enum
  (drift / sqflite / memory) make the storage engine a `const` config constant,
  not something wired into callers. sqflite/memory are deliberate
  `UnimplementedError` seams — they prove the boundary without paying for
  engines the app does not use.
- **Two stores, one API.** Persistent and cache differ only by method prefix and
  TTL, so a single interface serves both. Cache rows carry a nullable
  `expiresAt`; persistent rows carry a non-null `updatedAt`.
- **Raw-string drift layer.** Tables are `key TEXT PK, value TEXT`. Every typed
  value is JSON-encoded one layer up, so the schema is domain-independent and
  `schemaVersion` stays `1` forever — adding a new cached type never touches the
  DB schema.
- **TTL at the engine, not just the app.** Expired cache rows are purged lazily
  on read / watch, so stale data never leaks even if an app-level lifetime check
  is bypassed. Prefer this engine-TTL path (`DriftDatabaseCache`) over a
  sidecar-timestamp approach.
- **Cache as a use-case hook.** The use-case base exposes `cache()` + `key`
  overrides; opting a query into caching is two overrides and zero branching in
  call sites. The base `call()` composes cache + producer + the
  `Either<AppError, T>` error funnel (see `04-usecases.md`).
- **Secrets never touch the DB.** Tokens and keys go to hardware-backed storage
  behind their own abstraction — different threat model, different API.

## Folder placement

```
lib/
  cache/
    cache.dart                     # Cache<T> + FuCache<T> + DriftDatabaseCache<T>
                                   #   + AbstractCacheJsonParser<T> + CacheKeys enum
  database/
    abstract_database.dart         # AbstractDatabase + Database typedef
                                   #   + DatabaseProvider enum + DatabaseConfig + DatabaseFactory
    secure_storage.dart            # AbstractFlutterSecureStorage + FlutterSecureStorageImpl
    drift/
      example_table.dart           # drift Table defs (cache + persistent), raw KV
      app_database.dart            # drift DBs (CacheDatabase/PersistentDatabase) + DriftDatabase engine
      app_database.g.dart          # build_runner output — committed, never hand-edited
  di/
    abstract_binding.dart          # AbstractBinding base (see 03-di.md)
    database/
      database_binding.dart        # GetIt registration: secure storage (sync) + DB (async)
```

`*.g.dart` is build_runner output: generate with
`dart run build_runner build --delete-conflicting-outputs`, commit it, never
edit it by hand — the `$CacheDatabase` / `$PersistentDatabase` superclasses come
from it.

## Templates

Copy from `assets/templates/cache/`. The cache/DB/secure-storage/binding files
are **shared infrastructure — copy them ONCE per app**, not per concern; only the
table file and the cache-keys enum get renamed per cached entity.

| File | What it is |
|---|---|
| [`abstract_database.dart`](../assets/templates/cache/abstract_database.dart) | The engine-agnostic `AbstractDatabase` interface, the `Database` typedef alias, the `DatabaseProvider` enum, `DatabaseConfig` (provider as a `const`), and the `DatabaseFactory` (switch on provider; drift built, others stubbed). |
| [`example_table.dart`](../assets/templates/cache/example_table.dart) | drift `Table` definitions — raw `key/value` KV. Cache table carries `expiresAt` (TTL); persistent table carries `updatedAt`. Rename the `Example` anchor per namespace. |
| [`app_database.dart`](../assets/templates/cache/app_database.dart) | The two drift databases (one table each) and the `DriftDatabase` engine: typed JSON codec, key/value validation, and **lazy TTL purge on read / watch**. Holds the `part 'app_database.g.dart'` codegen directive. |
| [`cache.dart`](../assets/templates/cache/cache.dart) | The decorator chain: `Cache<T>` (serialize-only), `FuCache<T>` (cache-aside, implements `CacheStore<T>`), `DriftDatabaseCache<T>` (engine-TTL over `AbstractDatabase`), the `AbstractCacheJsonParser<T>` strategy, and the cache-keys enum. |
| [`secure_storage.dart`](../assets/templates/cache/secure_storage.dart) | `AbstractFlutterSecureStorage` interface + `FlutterSecureStorageImpl` (Keychain / Keystore, `encryptedSharedPreferences` on Android). The secrets path. |
| [`database_binding.dart`](../assets/templates/cache/database_binding.dart) | GetIt registration: secure storage `registerSingleton` (sync), DB `registerSingletonAsync` (awaits `init()`). Slots into DI phase 1. |

`CacheStore<T>` itself is declared in the use-case base (`abstract_use_case.dart`,
see `04-usecases.md`) — this layer's `FuCache<T>` is the concrete implementation
of it, which is why caching wires in with no extra interface in the domain layer.

## Step-by-step to apply

**Stand up the layer (once per app):**

1. **Copy the infrastructure files.** `abstract_database.dart`,
   `app_database.dart`, `example_table.dart`, `cache.dart`,
   `secure_storage.dart`, `database_binding.dart` into the folders above. Leave
   the `Database` typedef, `DatabaseProvider` enum, and `DatabaseConfig.provider`
   = `drift` as-is.
2. **Codegen the drift parts.** Run
   `dart run build_runner build --delete-conflicting-outputs` to emit
   `app_database.g.dart` (the `$CacheDatabase` / `$PersistentDatabase`
   superclasses). Commit it.
3. **Register in DI.** Add `DatabaseBinding` to the **phase-1 infrastructure**
   binding list in `AppDI`, before any repository or feature that reads the
   cache. Consumers resolve the DB with `await it.getAsync<Database>()` (it is
   async-registered); secure storage resolves synchronously
   (`it<AbstractFlutterSecureStorage>()`). See `03-di.md`.
4. **Confirm `pubspec.yaml`** has `drift`, `drift_flutter`, and
   `flutter_secure_storage` (and `drift_dev` + `build_runner` under
   `dev_dependencies`).

**Cache a use case's result (the common per-feature task):**

5. **Add a cache key.** Add a value to the cache-keys enum in `cache.dart`
   (`ExampleCacheKeys.findExampleById`). Reference it as `…​.name` — never a
   string literal.
6. **Override `cache()` + `key` on the use case.** In the concrete use case
   (`04-usecases.md`), override `String? get key => ExampleCacheKeys.x.name;` and
   `cache(params)` to return
   `FuCache(DriftDatabaseCache(db, environment: AppDI.it(), jsonParse: ExampleJsonParse()))`.
   The base `call()` plumbs `forceRefresh` and composes the producer with the
   cache automatically. `execute()` stays pure happy-path.
7. **Provide a JSON parser.** Implement `AbstractCacheJsonParser<T>` for the
   cached type (for a Freezed DTO this is just `dto.toJson()` /
   `Dto.fromJson(json)`). It must expect collection input — `get` only routes
   `Map`/`List` through `fromJson`; primitives are cast directly.

**Persist durably / store a secret:**

8. **Durable value:** call `db.writePersistent(key, value)` /
   `db.readPersistent<T>(key)`. No TTL; survives launches.
9. **Secret:** resolve `AbstractFlutterSecureStorage` and call
   `write` / `read` / `delete`. Do **not** route secrets through the drift store.

## Gotchas

- **`*.g.dart` is generated.** Regenerate with build_runner; never hand-edit.
  It must be committed — the codegen `$CacheDatabase` / `$PersistentDatabase`
  superclasses do not exist without it, so the project will not compile.
- **Engine-TTL vs sidecar-timestamp — pick one.** `DriftDatabaseCache` delegates
  expiry to the engine (`expiresAt` column). Do not also store a
  `<key>_create_at` sidecar for the same key; mixing the two double-stores
  metadata and the two clocks can disagree. Prefer engine-TTL everywhere.
- **The parser only fires on collections.** `DriftDatabaseCache.get` routes
  through `jsonParse.fromJson` only when the decoded value is a `Map` or `List`;
  primitives bypass the parser and are cast directly. A parser written to expect
  a scalar will never be called.
- **`_decode<T>` blind-casts non-`String` types.** It JSON-decodes and casts to
  `T`; a wrong-shaped body surfaces as a cast error, which the use-case base
  catches and turns into a `Left(UnknownException)`. Do not rely on the decode
  to validate shape.
- **The DB is async-registered.** Resolve it with `getAsync<Database>()`, not
  `it<Database>()` — a sync resolve before `init()` completes throws
  "not ready". Secure storage is the opposite: sync `registerSingleton`.
- **Cache globally off when `Environment.isEnableCache == false`.** `save`/`get`
  silently return `null`, so the producer runs every time. Intended (a global
  kill-switch), but easy to misread as a cache-miss bug.
- **`findKeys` is O(n).** It loads keys and filters in Dart with a regex built
  from `*`/`?` — not a SQL `LIKE`. Fine for a small KV store, not for large
  tables.
- **Two DB files by design.** Persistent and cache are separate drift files, so
  clearing the cache never risks the durable store. Do not collapse them into
  one DB to "save a file" — the split is the safety boundary.
- **`shareAcrossIsolates: true`** is set on the native drift connection so a
  background isolate shares the one DB. Keep it; dropping it causes a second
  isolate to open a separate, divergent connection.

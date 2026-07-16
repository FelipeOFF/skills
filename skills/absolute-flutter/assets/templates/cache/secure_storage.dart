// lib/database/secure_storage.dart
//
// Secrets path, deliberately SEPARATE from AbstractDatabase. Tokens / keys go
// to the platform Keychain (iOS) / Keystore (Android) via flutter_secure_storage
// — never into the drift KV store. Behind its own abstraction so call sites
// depend on the interface and tests can fake it.
//
// Rename anchor: none — shared infrastructure, copy ONCE per app.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Hardware-backed secret store contract. The interface is `const`-constructible
/// so the impl can be a `const` singleton registered synchronously in DI.
abstract class AbstractFlutterSecureStorage {
  const AbstractFlutterSecureStorage();

  Future<void> write({required String key, required String? value});

  Future<String?> read({required String key});

  Future<bool> containsKey({required String key});

  Future<void> delete({required String key});
}

/// flutter_secure_storage-backed impl. Delegates to one shared plugin instance
/// configured with `encryptedSharedPreferences` on Android so secrets land in
/// the Keystore-backed store rather than plaintext prefs.
class FlutterSecureStorageImpl extends AbstractFlutterSecureStorage {
  const FlutterSecureStorageImpl();

  static const FlutterSecureStorage _shared = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> write({required String key, required String? value}) => _shared.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _shared.read(key: key);

  @override
  Future<bool> containsKey({required String key}) => _shared.containsKey(key: key);

  @override
  Future<void> delete({required String key}) => _shared.delete(key: key);
}

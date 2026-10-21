import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The key itself must never be written to SharedPreferences, cloud sync,
/// analytics, database metadata, error messages, or source control.
///
/// These keys are device-bound. A multi-device backup/recovery key protocol
/// must be designed separately before remote sync is enabled.
abstract interface class WaffraVaultKeyStore {
  Future<String?> readKey(String vaultId);
  Future<void> writeKey(String vaultId, String value);
}

/// Platform secure storage is backed by Keychain on iOS and an Android
/// Keystore-backed encrypted storage mechanism on Android.
///
/// IMPORTANT: Exclude app databases and wrapped keys from automatic OS
/// backups until tested recovery/key restoration is implemented.
class WaffraPlatformVaultKeyStore implements WaffraVaultKeyStore {
  WaffraPlatformVaultKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _storageKey(String id) => 'waffra_vault_encryption_key_v1_$id';

  @override
  Future<String?> readKey(String vaultId) =>
      _storage.read(key: _storageKey(vaultId));

  @override
  Future<void> writeKey(String vaultId, String value) =>
      _storage.write(key: _storageKey(vaultId), value: value);
}

/// Produces 256 bits of unpredictable secret material per independent vault.
///
/// Key loss is fatal for an existing encrypted database: NEVER transparently
/// generate a replacement key for an existing database or delete its contents.
class WaffraVaultKeyManager {
  WaffraVaultKeyManager(this._store);

  final WaffraVaultKeyStore _store;

  Future<String> getOrCreate({
    required String vaultId,
    required File databaseFile,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(vaultId)) {
      throw ArgumentError.value(vaultId, 'vaultId', 'Invalid vault identifier');
    }

    final existing = await _store.readKey(vaultId);
    if (existing != null) {
      if (!_isValidKey(existing)) {
        throw StateError('Vault encryption key cannot be read');
      }
      return existing;
    }

    if (await databaseFile.exists()) {
      // This includes the case where iOS or Android restored only the DB,
      // but not the non-exportable device-wrapped key. Fail closed.
      throw StateError('Vault encryption key is missing for an existing database');
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes);

    await _store.writeKey(vaultId, generated);
    // A failed secure storage write must never create an unopenable DB.
    final readBack = await _store.readKey(vaultId);
    if (readBack != generated) {
      throw StateError('Vault encryption key could not be persisted');
    }
    return generated;
  }

  static bool _isValidKey(String value) {
    try {
      return base64Url.decode(value).length == 32;
    } on FormatException {
      return false;
    }
  }
}

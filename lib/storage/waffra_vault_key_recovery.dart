import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Standalone E2EE key-recovery primitive for a FUTURE explicitly opted-in
/// sync vault. The recovery code is a randomly generated 256-bit secret,
/// NOT a human-selected password; no weak-password KDF assumption is made.
/// Never upload/log/store the recovery code or an unwrapped vault key.
///
/// No UI, Firebase SDK, cloud writes or live sign-in binding is included.
class WaffraVaultKeyRecovery {
  WaffraVaultKeyRecovery() : _aes = AesGcm.with256bits();

  final AesGcm _aes;

  static void _checkIdentity(String vaultId, int keyVersion, int revision) {
    if (vaultId.trim().isEmpty || vaultId.length > 128 ||
        vaultId.contains('/') || keyVersion < 1 || revision < 1) {
      throw ArgumentError('Invalid recovery envelope metadata.');
    }
  }

  static List<int> _aad(String vaultId, int keyVersion, int revision) =>
      utf8.encode(jsonEncode([
        'waffra-vault-recovery', 1, vaultId, keyVersion, revision
      ]));

  static String _encodeCode(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  static List<int> _decodeRecoveryCode(String code) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) {
      throw const FormatException('Invalid recovery code format.');
    }
    final decoded = base64Url.decode(code + '=');
    if (decoded.length != 32 || _encodeCode(decoded) != code) {
      throw const FormatException('Noncanonical recovery code.');
    }
    return decoded;
  }

  /// Create a one-time displayable recovery code and uploadable ciphertext
  /// envelope, without ever disclosing plaintext vault key to the network.
  Future<WaffraVaultRecoveryBundle> create({
    required SecretKey vaultKey,
    required String vaultId,
    int keyVersion = 1,
    int recoveryRevision = 1,
  }) async {
    _checkIdentity(vaultId, keyVersion, recoveryRevision);
    final unwrapped = await vaultKey.extractBytes();
    if (unwrapped.length != 32) {
      throw ArgumentError('Vault encryption key must be 256 bits.');
    }
    final recoverySecret = await _aes.newSecretKey();
    final recoveryBytes = await recoverySecret.extractBytes();
    if (recoveryBytes.length != 32) {
      throw StateError('Failed to generate a 256-bit recovery secret.');
    }
    final box = await _aes.encrypt(
      unwrapped,
      secretKey: recoverySecret,
      aad: _aad(vaultId, keyVersion, recoveryRevision),
    );
    return WaffraVaultRecoveryBundle(
      recoveryCode: _encodeCode(recoveryBytes),
      envelope: WaffraVaultRecoveryEnvelope(
        vaultId: vaultId,
        keyVersion: keyVersion,
        recoveryRevision: recoveryRevision,
        wrappedKey: base64Encode(box.cipherText),
        nonce: base64Encode(box.nonce),
        mac: base64Encode(box.mac.bytes),
      ),
    );
  }

  /// Client-side only: requires the user-provided recovery code.
  /// Authentication/login alone is NEVER sufficient to unwrap the vault.
  Future<SecretKey> recover({
    required String vaultId,
    required String recoveryCode,
    required WaffraVaultRecoveryEnvelope envelope,
  }) async {
    _checkIdentity(envelope.vaultId,
        envelope.keyVersion, envelope.recoveryRevision);
    if (vaultId != envelope.vaultId) {
      throw StateError('Recovery package does not belong to this vault.');
    }
    if (envelope.schemaVersion != 1) {
      throw const FormatException('Unsupported recovery envelope schema.');
    }
    final codeBytes = _decodeRecoveryCode(recoveryCode);
    final encrypted = base64Decode(envelope.wrappedKey);
    final nonce = base64Decode(envelope.nonce);
    final mac = base64Decode(envelope.mac);
    if (encrypted.length != 32 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Invalid vault recovery envelope sizes.');
    }
    final plaintext = await _aes.decrypt(
      SecretBox(encrypted, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(codeBytes),
      aad: _aad(vaultId, envelope.keyVersion, envelope.recoveryRevision),
    );
    if (plaintext.length != 32) {
      throw const FormatException('Invalid recovered vault key length.');
    }
    return SecretKey(plaintext);
  }

  /// Rotate the HUMAN recovery code, not the underlying ledger key.
  /// The old code becomes unusable only after the new envelope replaces
  /// the previous envelope atomically at the authoritative remote location.
  Future<WaffraVaultRecoveryBundle> rotateCode({
    required SecretKey vaultKey,
    required WaffraVaultRecoveryEnvelope previous,
  }) {
    if (previous.recoveryRevision >= 2147483647) {
      throw StateError('Recovery revision exhausted.');
    }
    return create(
      vaultKey: vaultKey,
      vaultId: previous.vaultId,
      keyVersion: previous.keyVersion,
      recoveryRevision: previous.recoveryRevision + 1,
    );
  }
}

/// Display the recovery code to the user once. Never send this bundle to
/// Firebase: only its [envelope] is suitable for upload after consent.
class WaffraVaultRecoveryBundle {
  const WaffraVaultRecoveryBundle({
    required this.recoveryCode,
    required this.envelope,
  });
  final String recoveryCode;
  final WaffraVaultRecoveryEnvelope envelope;
}

class WaffraVaultRecoveryEnvelope {
  const WaffraVaultRecoveryEnvelope({
    required this.vaultId,
    required this.keyVersion,
    required this.recoveryRevision,
    required this.wrappedKey,
    required this.nonce,
    required this.mac,
    this.schemaVersion = 1,
  });
  final String vaultId, wrappedKey, nonce, mac;
  final int schemaVersion, keyVersion, recoveryRevision;

  /// Only public metadata and encrypted bytes; NEVER the recovery code.
  Map<String, Object> toPublicDocument() => {
    'schemaVersion': schemaVersion,
    'vaultId': vaultId,
    'keyVersion': keyVersion,
    'recoveryRevision': recoveryRevision,
    'wrappedKey': wrappedKey,
    'nonce': nonce,
    'mac': mac,
  };

  static WaffraVaultRecoveryEnvelope fromPublicDocument(
      Map<String, dynamic> data) {
    const expected = <String>{
      'schemaVersion', 'vaultId', 'keyVersion', 'recoveryRevision',
      'wrappedKey', 'nonce', 'mac',
    };
    if (data.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(data.keys.toSet()).isNotEmpty ||
        data['schemaVersion'] != 1 ||
        data['vaultId'] is! String ||
        data['keyVersion'] is! int ||
        data['recoveryRevision'] is! int ||
        data['wrappedKey'] is! String ||
        data['nonce'] is! String ||
        data['mac'] is! String) {
      throw const FormatException('Unrecognized vault recovery document.');
    }
    return WaffraVaultRecoveryEnvelope(
      vaultId: data['vaultId'] as String,
      keyVersion: data['keyVersion'] as int,
      recoveryRevision: data['recoveryRevision'] as int,
      wrappedKey: data['wrappedKey'] as String,
      nonce: data['nonce'] as String,
      mac: data['mac'] as String,
    );
  }
}

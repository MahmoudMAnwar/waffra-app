import 'package:cryptography/cryptography.dart';

import 'waffra_cloud_cipher.dart';

/// Public Firestore metadata never contains IDs/merchant names or plaintext
/// totals. This index is encrypted with the SAME user-held vault key as the
/// finance records. It lets a recovered device discover what to download.
class WaffraCloudRecoveryManifest {
  const WaffraCloudRecoveryManifest._();

  static const recordId = 'finance-index';
  static const kind = 'manifest';

  /// Build an authenticated index that MUST be published after its referenced
  /// records have been committed remotely. Otherwise recovery rejects it.
  /// Never upload this Map unencrypted.
  static Future<WaffraEncryptedCloudRecord> encrypt({
    required SecretKey recoveredVaultKey,
    required String vaultId,
    required String deviceId,
    required String mutationId,
    required int version,
    required List<WaffraCloudRecordPointer> records,
  }) async {
    if (records.length > 1000) {
      throw StateError('Encrypted recovery index exceeds review limit.');
    }
    return WaffraCloudCipher().encrypt(
      vaultKey: recoveredVaultKey,
      vaultId: vaultId,
      kind: kind,
      recordId: recordId,
      deviceId: deviceId,
      mutationId: mutationId,
      localVersion: version,
      record: {
        'id': recordId,
        'records': [
          for (final entry in records) entry.toJson(),
        ],
      },
    );
  }

  static Future<List<WaffraCloudRecordPointer>> decrypt({
    required SecretKey recoveredVaultKey,
    required String vaultId,
    required WaffraEncryptedCloudRecord manifest,
  }) async {
    if (manifest.kind != kind || manifest.recordId != recordId) {
      throw StateError('Recovery index identity does not match.');
    }
    final decoded = await WaffraCloudCipher().decrypt(
      vaultKey: recoveredVaultKey,
      vaultId: vaultId,
      envelope: manifest,
    );
    if (decoded['id'] != recordId || decoded['records'] is! List) {
      throw StateError('Malformed encrypted cloud recovery index.');
    }
    final pointers = <WaffraCloudRecordPointer>[];
    final seen = <String>{};
    for (final part in decoded['records'] as List) {
      if (part is! Map<String, dynamic>) {
        throw StateError('Malformed encrypted cloud recovery pointer.');
      }
      final pointer = WaffraCloudRecordPointer.fromJson(part);
      if (!seen.add('${pointer.kind}/${pointer.id}')) {
        throw StateError('Duplicate encrypted recovery record pointer.');
      }
      pointers.add(pointer);
    }
    return List<WaffraCloudRecordPointer>.unmodifiable(pointers);
  }
}

class WaffraCloudRecordPointer {
  const WaffraCloudRecordPointer({
    required this.kind,
    required this.id,
    required this.mutationId,
    required this.version,
    required this.deleted,
  });

  final String kind, id, mutationId;
  final int version;
  final bool deleted;

  Map<String, Object> toJson() => {
    'kind': kind,
    'id': id,
    'mutationId': mutationId,
    'version': version,
    'deleted': deleted,
  };

  static WaffraCloudRecordPointer fromJson(Map<String, dynamic> data) {
    final verified = WaffraCloudSanitizer.sanitize('manifest', {
      'id': WaffraCloudRecoveryManifest.recordId,
      'records': [data],
    });
    final row = (verified['records'] as List).single as Map;
    return WaffraCloudRecordPointer(
      kind: row['kind'] as String,
      id: row['id'] as String,
      mutationId: row['mutationId'] as String,
      version: row['version'] as int,
      deleted: row['deleted'] as bool,
    );
  }
}

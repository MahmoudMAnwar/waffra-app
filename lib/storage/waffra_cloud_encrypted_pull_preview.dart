import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'waffra_cloud_cipher.dart';
import 'waffra_cloud_recovery_manifest.dart';
import 'waffra_firestore_encrypted_sync_transport.dart';
import 'waffra_sync_outbox.dart';

class WaffraVerifiedCloudRecordPreview {
  const WaffraVerifiedCloudRecordPreview({
    required this.documentId,
    required this.kind,
    required this.recordId,
    required this.mutationId,
    required this.remoteVersion,
    required this.deleted,
    required this.clearRecord,
  });

  final String documentId, kind, recordId, mutationId;
  final int remoteVersion;
  final bool deleted;
  final Map<String, dynamic> clearRecord;
}

/// Read-only remote recovery PREVIEW for records whose (kind, recordId) are
/// already known locally. Does not invent missing finance, commit to SQLCipher,
/// upload plaintext, or implement a cross-device merge.
///
/// New devices still require a separately verified encrypted manifest of IDs,
/// key recovery and an atomic local reconciliation protocol before live sync.
class WaffraCloudEncryptedPullPreview {
  const WaffraCloudEncryptedPullPreview({
    required this.firestore,
    required this.auth,
    this.experimentalEnabled = false,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final bool experimentalEnabled;

  static WaffraEncryptedCloudRecord parseEnvelope({
    required String kind,
    required String documentId,
    required String recordId,
    required Map<String, dynamic> remote,
  }) {
    const permitted = {
      'kind', 'ciphertext', 'nonce', 'mac', 'encryptionVersion',
      'deviceId', 'mutationId', 'localVersion', 'updatedAt', 'deleted',
    };
    if (remote.keys.toSet().difference(permitted).isNotEmpty ||
        remote.keys.toSet().length != permitted.length ||
        !remote.keys.toSet().containsAll(permitted) ||
        documentId != WaffraEncryptedCloudOutbox.documentId(kind, recordId) ||
        remote['kind'] != kind ||
        remote['encryptionVersion'] != 1 ||
        remote['ciphertext'] is! String ||
        remote['nonce'] is! String ||
        remote['mac'] is! String ||
        remote['deviceId'] is! String ||
        remote['mutationId'] is! String ||
        remote['localVersion'] is! int ||
        (remote['localVersion'] as int) <= 0 ||
        remote['deleted'] is! bool) {
      throw StateError('Untrusted encrypted cloud finance envelope.');
    }
    return WaffraEncryptedCloudRecord(
      kind: kind,
      recordId: recordId,
      deviceId: remote['deviceId'] as String,
      mutationId: remote['mutationId'] as String,
      localVersion: remote['localVersion'] as int,
      encryptionVersion: remote['encryptionVersion'] as int,
      ciphertext: remote['ciphertext'] as String,
      nonce: remote['nonce'] as String,
      mac: remote['mac'] as String,
    );
  }

  /// A new phone does not know financial record IDs. Decrypt a versioned
  /// authenticated manifest FIRST, then prove every referenced revision
  /// exists and authenticates under the recovered vault key.
  ///
  /// This is a read-only, all-or-error preview: it NEVER automatically
  /// merges, deletes or overwrites the existing device's SQLCipher data.
  /// Publishing the manifest is ordered AFTER all referenced uploads.
  Future<List<WaffraVerifiedCloudRecordPreview>> previewIndexedVault({
    required String ownerUid,
    required String vaultId,
    required SecretKey recoveredKey,
    required WaffraCloudSyncAuthorization authorization,
  }) async {
    final index = await previewKnownRecord(
      ownerUid: ownerUid,
      vaultId: vaultId,
      kind: WaffraCloudRecoveryManifest.kind,
      recordId: WaffraCloudRecoveryManifest.recordId,
      recoveredKey: recoveredKey,
      authorization: authorization,
    );
    if (index == null || index.deleted) {
      throw StateError('Missing valid encrypted recovery inventory.');
    }
    final raw = index.clearRecord['records'];
    if (raw is! List || raw.length > 1000) {
      throw StateError('Encrypted recovery inventory is malformed.');
    }
    final results = <WaffraVerifiedCloudRecordPreview>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Encrypted recovery pointer is malformed.');
      }
      final pointer = WaffraCloudRecordPointer.fromJson(item);
      if (!seen.add('${pointer.kind}/${pointer.id}')) {
        throw StateError('Duplicate encrypted record in recovery inventory.');
      }
      final candidate = await previewKnownRecord(
        ownerUid: ownerUid,
        vaultId: vaultId,
        kind: pointer.kind,
        recordId: pointer.id,
        recoveredKey: recoveredKey,
        authorization: authorization,
      );
      if (candidate == null ||
          candidate.mutationId != pointer.mutationId ||
          candidate.remoteVersion != pointer.version ||
          candidate.deleted != pointer.deleted) {
        throw StateError('Cloud data diverged from encrypted recovery index.');
      }
      results.add(candidate);
    }
    return List<WaffraVerifiedCloudRecordPreview>.unmodifiable(results);
  }

  Future<WaffraVerifiedCloudRecordPreview?> previewKnownRecord({
    required String ownerUid,
    required String vaultId,
    required String kind,
    required String recordId,
    required SecretKey recoveredKey,
    required WaffraCloudSyncAuthorization authorization,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      throw StateError('Encrypted cloud recovery is not authorized.');
    }
    if (ownerUid.isEmpty || ownerUid.contains('/') ||
        vaultId.isEmpty || vaultId.contains('/') ||
        auth.currentUser?.uid != ownerUid) {
      throw StateError('Cloud recovery owner is not authenticated.');
    }
    final root = firestore.collection('users').doc(ownerUid)
        .collection('vaults').doc(vaultId);
    final parent = await root.get(const GetOptions(source: Source.server));
    if (!parent.exists || parent.data()?['ownerUid'] != ownerUid ||
        parent.data()?['schemaVersion'] != 1 ||
        parent.data()?['syncEnabled'] != true) {
      throw StateError('Cloud vault consent or ownership is missing.');
    }
    final documentId = WaffraEncryptedCloudOutbox.documentId(kind, recordId);
    final response = await root.collection('records').doc(documentId)
        .get(const GetOptions(source: Source.server));
    if (!response.exists) {
      // Absence is NEVER permission to delete an existing local record.
      return null;
    }
    final data = response.data();
    if (data == null) throw StateError('Encrypted cloud record has no data.');
    final envelope = parseEnvelope(
      kind: kind, documentId: documentId,
      recordId: recordId, remote: data,
    );
    // AES-GCM authenticates the content and AAD binding the vault, type,
    // record ID, device ID, mutation ID and strictly increasing revision.
    final decoded = await WaffraCloudCipher().decrypt(
      vaultKey: recoveredKey,
      vaultId: vaultId,
      envelope: envelope,
    );
    return WaffraVerifiedCloudRecordPreview(
      documentId: documentId,
      kind: kind,
      recordId: recordId,
      mutationId: envelope.mutationId,
      remoteVersion: envelope.localVersion,
      deleted: data['deleted'] as bool,
      clearRecord: Map<String, dynamic>.unmodifiable(decoded),
    );
  }
}

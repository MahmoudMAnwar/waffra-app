import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'waffra_sync_outbox.dart';

/// Consent and key/source proofs must come from a verified, independent
/// production coordinator. Authentication alone never authorizes uploads.
class WaffraCloudSyncAuthorization {
  const WaffraCloudSyncAuthorization({
    this.userConsented = false,
    this.recoveryKeyVerified = false,
    this.encryptedSourceVerified = false,
    this.allWritersRouted = false,
  });
  final bool userConsented;
  final bool recoveryKeyVerified;
  final bool encryptedSourceVerified;
  final bool allWritersRouted;

  bool get canUpload => userConsented && recoveryKeyVerified &&
      encryptedSourceVerified && allWritersRouted;
}

/// Transactional, client-side-encrypted transport for already prepared
/// SQLCipher outbox envelopes. Not enabled in main.dart. No banking API.
///
/// Existing record revisions require the EXPECTED prior mutation ID observed
/// when the local change was prepared, in addition to exact version + 1.
/// Competing devices fail closed and must be reconciled, never LWW.
class WaffraFirestoreEncryptedSyncTransport {
  const WaffraFirestoreEncryptedSyncTransport({
    required this.firestore,
    required this.auth,
    required this.outbox,
    this.experimentalEnabled = false,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final WaffraEncryptedCloudOutbox outbox;
  final bool experimentalEnabled;

  Future<WaffraCloudPublishResult> publish({
    required String ownerUid,
    required WaffraCloudQueueItem item,
    required WaffraCloudSyncAuthorization authorization,
    String? expectedPreviousMutationId,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      return const WaffraCloudPublishResult(
        status: WaffraCloudPublishStatus.blocked,
      );
    }
    if (ownerUid.isEmpty || ownerUid.contains('/') ||
        item.vaultId.isEmpty || item.vaultId.contains('/') ||
        item.documentId.isEmpty || item.documentId.contains('/') ||
        auth.currentUser?.uid != ownerUid ||
        WaffraEncryptedCloudOutbox.documentId(
          item.envelope.kind, item.envelope.recordId,
        ) != item.documentId) {
      throw StateError('Authenticated cloud source identity mismatch.');
    }
    final vault = firestore.collection('users').doc(ownerUid)
        .collection('vaults').doc(item.vaultId);
    final record = vault.collection('records').doc(item.documentId);

    final applied = await firestore.runTransaction<WaffraCloudPublishStatus>(
      (tx) async {
        final parent = await tx.get(vault);
        final metadata = parent.data();
        if (!parent.exists || metadata == null ||
            metadata['ownerUid'] != ownerUid ||
            metadata['syncEnabled'] != true ||
            metadata['schemaVersion'] != 1) {
          throw StateError('Verified opt-in cloud vault does not exist.');
        }
        final current = await tx.get(record);
        final remote = current.exists
            ? _decodeRevision(item.documentId, current.data())
            : null;
        final decision = WaffraEncryptedCloudOutbox.preflight(
          item: item,
          remote: remote,
          consentGiven: authorization.userConsented,
          identityVerified: true,
          recoveryReady: authorization.recoveryKeyVerified,
          atomicRemoteTransportReady: true,
        );
        if (decision == WaffraRemoteAction.alreadyApplied) {
          return WaffraCloudPublishStatus.alreadyApplied;
        }
        if (decision == WaffraRemoteAction.blocked) {
          return WaffraCloudPublishStatus.blocked;
        }
        if (remote != null) {
          if (expectedPreviousMutationId == null ||
              expectedPreviousMutationId != remote.mutationId ||
              remote.kind != item.envelope.kind ||
              remote.localVersion + 1 != item.envelope.localVersion ||
              remote.mutationId == item.envelope.mutationId) {
            return WaffraCloudPublishStatus.manualConflict;
          }
        } else if (item.envelope.localVersion != 1 ||
            expectedPreviousMutationId != null) {
          // A missing server document with version >1 is not a new record:
          // it may be missing an earlier upload or a remote deletion.
          return WaffraCloudPublishStatus.manualConflict;
        }
        tx.set(record, <String, Object>{
          ...item.envelope.toFirestoreDocument(deleted: item.deleted),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return remote == null
            ? WaffraCloudPublishStatus.created
            : WaffraCloudPublishStatus.compareAndSwapped;
      },
      maxAttempts: 5,
    );
    if (applied == WaffraCloudPublishStatus.created ||
        applied == WaffraCloudPublishStatus.compareAndSwapped ||
        applied == WaffraCloudPublishStatus.alreadyApplied) {
      // The remote transaction has committed and proved this exact mutation.
      // Local acknowledgement is retry-safe and occurs ONLY afterwards.
      await outbox.acknowledge(
        item: item,
        confirmedRemote: WaffraRemoteRevision(
          documentId: item.documentId,
          kind: item.envelope.kind,
          mutationId: item.envelope.mutationId,
          deviceId: item.envelope.deviceId,
          localVersion: item.envelope.localVersion,
          ciphertext: item.envelope.ciphertext,
          nonce: item.envelope.nonce,
          mac: item.envelope.mac,
          deleted: item.deleted,
        ),
      );
    }
    return WaffraCloudPublishResult(status: applied);
  }

  static WaffraRemoteRevision _decodeRevision(
    String documentId, Map<String, dynamic>? data,
  ) {
    if (data == null ||
        data['kind'] is! String ||
        data['mutationId'] is! String ||
        data['deviceId'] is! String ||
        data['localVersion'] is! int ||
        data['ciphertext'] is! String ||
        data['nonce'] is! String ||
        data['mac'] is! String ||
        data['deleted'] is! bool ||
        data['encryptionVersion'] != 1) {
      throw StateError('Unexpected or incomplete remote encrypted record.');
    }
    return WaffraRemoteRevision(
      documentId: documentId,
      kind: data['kind'] as String,
      mutationId: data['mutationId'] as String,
      deviceId: data['deviceId'] as String,
      localVersion: data['localVersion'] as int,
      ciphertext: data['ciphertext'] as String,
      nonce: data['nonce'] as String,
      mac: data['mac'] as String,
      deleted: data['deleted'] as bool,
    );
  }
}

enum WaffraCloudPublishStatus {
  blocked, created, compareAndSwapped, alreadyApplied, manualConflict,
}

class WaffraCloudPublishResult {
  const WaffraCloudPublishResult({required this.status});
  final WaffraCloudPublishStatus status;
  bool get confirmed => status == WaffraCloudPublishStatus.created ||
      status == WaffraCloudPublishStatus.compareAndSwapped ||
      status == WaffraCloudPublishStatus.alreadyApplied;
}

import 'waffra_cloud_encrypted_pull_preview.dart';
import 'waffra_sync_outbox.dart';

/// Verified remote snapshot is NOT enough to authorize replacing local money.
/// This pure barrier prevents accidental partial restore, stale tombstones and
/// cross-device reconciliation without a tested, explicit user decision.
class WaffraCloudRestoreProof {
  const WaffraCloudRestoreProof({
    this.userRequestedRestore = false,
    this.keyRecovered = false,
    this.allRemoteRecordsVerified = false,
    this.localVaultEmpty = false,
    this.localBackupAuthenticated = false,
    this.receiptsCompleteOrExplicitlyAbsent = false,
    this.rollbackVerified = false,
  });
  final bool userRequestedRestore, keyRecovered, allRemoteRecordsVerified;
  final bool localVaultEmpty, localBackupAuthenticated;
  final bool receiptsCompleteOrExplicitlyAbsent, rollbackVerified;

  bool get readyForEmptyVaultRestore => userRequestedRestore &&
      keyRecovered && allRemoteRecordsVerified && localVaultEmpty &&
      localBackupAuthenticated && receiptsCompleteOrExplicitlyAbsent &&
      rollbackVerified;
}

class WaffraCloudRecoveryRevisionGate {
  const WaffraCloudRecoveryRevisionGate._();

  /// Called only with the all-or-nothing result of previewIndexedVault.
  /// The method is deliberately read-only and never executes migration.
  static void verify({
    required List<WaffraVerifiedCloudRecordPreview> remote,
    required Map<String, int> expectedRevisions,
    required WaffraCloudRestoreProof proof,
  }) {
    if (!proof.readyForEmptyVaultRestore) {
      throw StateError('Encrypted cloud restore has unmet recovery gates.');
    }
    if (remote.length != expectedRevisions.length) {
      throw StateError('Encrypted index was partially fetched.');
    }
    final seen = <String>{};
    for (final item in remote) {
      if (item.kind == 'manifest' || item.kind.trim().isEmpty ||
          item.recordId.trim().isEmpty || item.mutationId.trim().isEmpty ||
          item.remoteVersion <= 0 ||
          item.documentId != WaffraEncryptedCloudOutbox.documentId(
            item.kind, item.recordId,
          )) {
        throw StateError('Remote identity is not a valid finance record.');
      }
      final name = '${item.kind}/${item.recordId}';
      if (!seen.add(name) ||
          expectedRevisions[name] != item.remoteVersion) {
        throw StateError('Remote recovery index differs from fetched data.');
      }
      // Deletions may be maintained as durable encrypted tombstones but
      // cannot silently erase or overwrite existing local history.
      if (item.deleted && item.clearRecord['id'] == item.recordId) {
        throw StateError(
          'Destructive cloud tombstone needs manual review.',
        );
      }
    }
    if (!seen.containsAll(expectedRevisions.keys)) {
      throw StateError('Missing encrypted records in restored inventory.');
    }
  }
}

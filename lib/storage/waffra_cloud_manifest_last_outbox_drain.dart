import 'waffra_cloud_recovery_manifest.dart';
import 'waffra_firestore_encrypted_sync_transport.dart';
import 'waffra_sync_outbox.dart';

/// Bound and auditable outcome; never claim full sync from individual writes.
class WaffraCloudDrainReport {
  const WaffraCloudDrainReport({
    required this.recordMutations,
    required this.manifestCommitted,
    required this.blocked,
    required this.manualConflict,
    required this.hasPending,
  });

  final int recordMutations;
  final bool manifestCommitted, blocked, manualConflict, hasPending;
  bool get fullySynced => !blocked && !manualConflict && !hasPending &&
      manifestCommitted;
}

typedef WaffraPublishEncryptedMutation = Future<WaffraCloudPublishResult>
    Function(WaffraCloudQueueItem item, String? expectedMutation);

/// Uploads encrypted finance mutations BEFORE the encrypted recovery index.
/// A new device must never read an index pointing to an uncommitted mutation.
///
/// Disabled by default. Call only from an opt-in, key-recovered, validated
/// SQLCipher runtime, after the *local* ledger+outbox transaction commits.
/// This never turns on Firebase, changes source pointers or resolves conflicts.
class WaffraCloudManifestLastOutboxDrain {
  const WaffraCloudManifestLastOutboxDrain({
    required this.outbox,
    required this.publishMutation,
    required this.verifyManifestReferences,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedCloudOutbox outbox;
  final WaffraPublishEncryptedMutation publishMutation;

  /// MUST verify all references in the immutable encrypted index against the
  /// latest committed remote revisions. A successful upload alone is not
  /// evidence that older/other-device references are still available.
  final Future<bool> Function(WaffraCloudQueueItem manifest)
      verifyManifestReferences;
  final bool experimentalEnabled;

  Future<WaffraCloudDrainReport> drain({
    required String vaultId,
    required WaffraCloudSyncAuthorization authorization,
    required Future<String?> Function(WaffraCloudQueueItem)
        expectedPreviousMutationId,
    int maxMutations = 2000,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      return const WaffraCloudDrainReport(
        recordMutations: 0, manifestCommitted: false,
        blocked: true, manualConflict: false, hasPending: true,
      );
    }
    if (vaultId.trim().isEmpty || vaultId.contains('/') ||
        maxMutations < 1 || maxMutations > 2000) {
      throw ArgumentError('Invalid encrypted sync drain limits.');
    }
    var completed = 0;
    var indexCommitted = false;
    bool blocked = false, conflict = false;
    // Always requery the authoritative SQLCipher outbox after EVERY server
    // ACK so no stale in-memory batch can jump ahead of another transaction.
    for (var i = 0; i < maxMutations; i++) {
      final pending = await outbox.pending(vaultId: vaultId, limit: 200);
      if (pending.isEmpty) break;
      final records = pending.where((item) =>
        !(item.envelope.kind == WaffraCloudRecoveryManifest.kind &&
          item.envelope.recordId == WaffraCloudRecoveryManifest.recordId),
      ).toList(growable: false);
      final item = records.isNotEmpty ? records.first : pending.first;
      final index = item.envelope.kind == WaffraCloudRecoveryManifest.kind;
      if (index) {
        if (item.envelope.recordId !=
                WaffraCloudRecoveryManifest.recordId ||
            item.deleted || !await verifyManifestReferences(item)) {
          blocked = true;
          break;
        }
      }
      // A revision >1 MUST include a verified expected remote mutation.
      // Null on an update would discard a competing phone's history.
      final expected = await expectedPreviousMutationId(item);
      if (item.envelope.localVersion > 1 &&
          (expected == null || expected.trim().isEmpty)) {
        blocked = true;
        break;
      }
      final result = await publishMutation(item, expected);
      if (result.status == WaffraCloudPublishStatus.manualConflict) {
        conflict = true;
        break;
      }
      if (!result.confirmed) {
        blocked = true;
        break;
      }
      if (index) {
        indexCommitted = true;
      } else {
        completed++;
      }
    }
    final remaining = await outbox.pending(vaultId: vaultId, limit: 200);
    return WaffraCloudDrainReport(
      recordMutations: completed,
      manifestCommitted: indexCommitted,
      blocked: blocked, manualConflict: conflict,
      hasPending: remaining.isNotEmpty,
    );
  }
}

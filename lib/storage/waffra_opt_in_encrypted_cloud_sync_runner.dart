import 'waffra_cloud_manifest_last_outbox_drain.dart';
import 'waffra_cloud_recovery_manifest.dart';
import 'waffra_cloud_remote_manifest_verifier.dart';
import 'waffra_firestore_encrypted_sync_transport.dart';
import 'waffra_sync_outbox.dart';

/// This is the actual Firestore transport wiring for the encrypted outbox:
/// one user-owned Firebase CAS mutation at a time, with the recovery index
/// published LAST after a fresh authenticated server-side record proof.
///
/// It is NOT an app startup worker. A verified production coordinator must
/// explicitly construct/enable this only after user consent, recovery-code
/// setup, all Home/Widget sources routed to SQLCipher and local outbox
/// creation in the same transaction as the financial mutation.
class WaffraOptInEncryptedCloudSyncRunner {
  const WaffraOptInEncryptedCloudSyncRunner({
    required this.transport,
    required this.outbox,
    required this.manifestVerifier,
    this.experimentalEnabled = false,
  });

  final WaffraFirestoreEncryptedSyncTransport transport;
  final WaffraEncryptedCloudOutbox outbox;
  final WaffraCloudRemoteManifestVerifier manifestVerifier;
  final bool experimentalEnabled;

  Future<WaffraCloudDrainReport> pushVerified({
    required String ownerUid,
    required String vaultId,
    required WaffraCloudSyncAuthorization authorization,
    required Future<String?> Function(WaffraCloudQueueItem)
        expectedPreviousMutationId,
  }) async {
    if (!experimentalEnabled || !authorization.canUpload) {
      return const WaffraCloudDrainReport(
        recordMutations: 0,
        manifestCommitted: false,
        blocked: true,
        manualConflict: false,
        hasPending: true,
      );
    }
    if (ownerUid.trim().isEmpty || ownerUid.contains('/') ||
        vaultId.trim().isEmpty || vaultId.contains('/') ||
        manifestVerifier.ownerUid != ownerUid ||
        manifestVerifier.vaultId != vaultId ||
        !manifestVerifier.experimentalEnabled ||
        !transport.experimentalEnabled) {
      throw StateError('Cloud finance source identity not verified.');
    }
    return WaffraCloudManifestLastOutboxDrain(
      outbox: outbox,
      experimentalEnabled: true,
      verifyManifestReferences: manifestVerifier.verify,
      publishMutation: (item, expectedMutation) =>
          transport.publish(
        ownerUid: ownerUid,
        item: item,
        authorization: authorization,
        expectedPreviousMutationId: expectedMutation,
        manifestVaultKey:
            item.envelope.kind == WaffraCloudRecoveryManifest.kind
                ? manifestVerifier.vaultKey
                : null,
      ),
    ).drain(
      vaultId: vaultId,
      authorization: authorization,
      expectedPreviousMutationId: expectedPreviousMutationId,
    );
  }
}

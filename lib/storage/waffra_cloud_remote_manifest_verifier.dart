import 'package:cryptography/cryptography.dart';

import 'waffra_cloud_encrypted_pull_preview.dart';
import 'waffra_cloud_recovery_manifest.dart';
import 'waffra_firestore_encrypted_sync_transport.dart';
import 'waffra_sync_outbox.dart';

/// A real remote revision verifier for the M99 manifest-last publisher.
/// No synthetic "all good" callback may be installed in a production worker.
/// Firebase reads come from Source.server inside previewKnownRecord; a stale
/// cached local record is never accepted as remote confirmation.
class WaffraCloudRemoteManifestVerifier {
  const WaffraCloudRemoteManifestVerifier({
    required this.preview,
    required this.vaultKey,
    required this.ownerUid,
    required this.vaultId,
    required this.authorization,
    this.experimentalEnabled = false,
  });

  final WaffraCloudEncryptedPullPreview preview;
  final SecretKey vaultKey;
  final String ownerUid;
  final String vaultId;
  final WaffraCloudSyncAuthorization authorization;
  final bool experimentalEnabled;

  Future<bool> verify(WaffraCloudQueueItem pendingManifest) async {
    if (!experimentalEnabled || !authorization.canUpload ||
        pendingManifest.vaultId != vaultId ||
        pendingManifest.deleted ||
        pendingManifest.documentId !=
            WaffraEncryptedCloudOutbox.documentId(
              WaffraCloudRecoveryManifest.kind,
              WaffraCloudRecoveryManifest.recordId,
            )) {
      return false;
    }
    return verifyWithSource(
      pendingManifest: pendingManifest,
      vaultKey: vaultKey,
      fetchRemote: (pointer) => preview.previewKnownRecord(
        ownerUid: ownerUid,
        vaultId: vaultId,
        kind: pointer.kind,
        recordId: pointer.id,
        recoveredKey: vaultKey,
        authorization: authorization,
      ),
    );
  }

  /// Testable cryptographic core; rejects any lost, substituted, stale or
  /// deleted record even if the manifest itself authenticated successfully.
  /// It MUST be run again for each attempted publication; the Firestore CAS
  /// transaction still decides who wins if another phone writes meanwhile.
  static Future<bool> verifyWithSource({
    required WaffraCloudQueueItem pendingManifest,
    required SecretKey vaultKey,
    required Future<WaffraVerifiedCloudRecordPreview?> Function(
      WaffraCloudRecordPointer pointer,
    ) fetchRemote,
  }) async {
    if (pendingManifest.deleted ||
        pendingManifest.envelope.kind !=
            WaffraCloudRecoveryManifest.kind ||
        pendingManifest.envelope.recordId !=
            WaffraCloudRecoveryManifest.recordId ||
        pendingManifest.documentId !=
            WaffraEncryptedCloudOutbox.documentId(
              WaffraCloudRecoveryManifest.kind,
              WaffraCloudRecoveryManifest.recordId,
            )) {
      return false;
    }
    final pointers = await WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: vaultKey,
      vaultId: pendingManifest.vaultId,
      manifest: pendingManifest.envelope,
    );
    for (final p in pointers) {
      final remote = await fetchRemote(p);
      if (remote == null ||
          remote.kind != p.kind ||
          remote.recordId != p.id ||
          remote.documentId !=
              WaffraEncryptedCloudOutbox.documentId(p.kind, p.id) ||
          remote.mutationId != p.mutationId ||
          remote.remoteVersion != p.version ||
          remote.deleted != p.deleted) {
        return false;
      }
    }
    return true;
  }
}

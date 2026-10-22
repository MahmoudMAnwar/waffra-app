import 'waffra_sync_outbox.dart';

/// A pure CAS planner evaluated against the CURRENT Firestore document inside
/// the same server transaction that commits a mutation. No network, UI,
/// automatic merge or source activation happens in this class.
enum WaffraCloudCasAction {
  create, alreadyApplied, advance, manualConflict,
}

class WaffraCloudCompareAndSwap {
  const WaffraCloudCompareAndSwap._();

  static WaffraCloudCasAction plan({
    required WaffraCloudQueueItem item,
    required WaffraRemoteRevision? remote,
    required String? expectedPreviousMutationId,
  }) {
    if (WaffraEncryptedCloudOutbox.documentId(
          item.envelope.kind, item.envelope.recordId,
        ) != item.documentId) {
      throw StateError('Cloud document does not match encrypted identity.');
    }
    if (remote == null) {
      return item.envelope.localVersion == 1 &&
          expectedPreviousMutationId == null
          ? WaffraCloudCasAction.create
          : WaffraCloudCasAction.manualConflict;
    }
    if (remote.documentId != item.documentId ||
        remote.kind != item.envelope.kind) {
      return WaffraCloudCasAction.manualConflict;
    }
    final prior = WaffraEncryptedCloudOutbox.preflight(
      item: item, remote: remote,
      consentGiven: true,
      identityVerified: true,
      recoveryReady: true,
      atomicRemoteTransportReady: true,
    );
    if (prior == WaffraRemoteAction.alreadyApplied) {
      return WaffraCloudCasAction.alreadyApplied;
    }

    // For a distinct mutation, the source must have explicitly observed
    // this EXACT predecessor before creating its encrypted local revision.
    // A stale off-device edit may not skip versions or overwrite same version.
    if (expectedPreviousMutationId != null &&
        expectedPreviousMutationId == remote.mutationId &&
        remote.localVersion + 1 == item.envelope.localVersion &&
        remote.mutationId != item.envelope.mutationId) {
      return WaffraCloudCasAction.advance;
    }
    return WaffraCloudCasAction.manualConflict;
  }
}

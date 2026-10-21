import 'waffra_sync_outbox.dart';

/// Testable contract for a FUTURE atomic Firestore transaction implementation.
/// An adapter MUST atomically read the current record and create-only or return
/// existing revision; naive set()/overwrite must never implement this contract.
/// Updating an existing remote financial record is intentionally NOT supported
/// until a separately verified compare-and-swap parent-revision protocol exists.
abstract class WaffraAtomicCreatePort {
  Future<WaffraAtomicCommitReceipt> createIfAbsent(
      WaffraCloudQueueItem item);
}

enum WaffraAtomicCommitStatus {
  created,
  alreadyApplied,
  conflict,
  temporarilyUnavailable,
}

class WaffraAtomicCommitReceipt {
  const WaffraAtomicCommitReceipt({
    required this.status,
    this.confirmedRevision,
  });
  final WaffraAtomicCommitStatus status;
  final WaffraRemoteRevision? confirmedRevision;
}

/// Explicit per-session release gates. The default blocks even locally
/// simulated cloud actions. This does not perform real Firebase permission
/// checks; production must obtain assertions from independently verified APIs.
class WaffraSyncReadiness {
  const WaffraSyncReadiness({
    this.userConsented = false,
    this.accountOwnershipVerified = false,
    this.recoveryVerified = false,
    this.firestoreRulesVerified = false,
    this.regionAndBillingVerified = false,
    this.transactionalAdapterVerified = false,
  });

  final bool userConsented;
  final bool accountOwnershipVerified;
  final bool recoveryVerified;
  final bool firestoreRulesVerified;
  final bool regionAndBillingVerified;
  final bool transactionalAdapterVerified;

  bool get allReady => userConsented && accountOwnershipVerified &&
      recoveryVerified && firestoreRulesVerified &&
      regionAndBillingVerified && transactionalAdapterVerified;
}

class WaffraSyncDryRunReport {
  const WaffraSyncDryRunReport({
    required this.pendingAttempted,
    required this.acknowledged,
    required this.conflicts,
    required this.retryLater,
  });
  final int pendingAttempted, acknowledged, conflicts, retryLater;
}

/// Transaction semantics dry-run; deliberately not wired into main.dart.
/// There is NO actual remote transport implementation in production sources.
/// A real adapter must prove its Firestore transaction + security-rule tests.
class WaffraSyncDryRunCoordinator {
  const WaffraSyncDryRunCoordinator({
    required this.outbox,
    required this.atomicPort,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedCloudOutbox outbox;
  final WaffraAtomicCreatePort atomicPort;
  final bool experimentalEnabled;

  /// No user data leaves the device unless a real port is installed. This
  /// prototype must only receive in-memory fake ports in offline testing.
  Future<WaffraSyncDryRunReport> processOnce({
    required String vaultId,
    required WaffraSyncReadiness readiness,
    int limit = 100,
  }) async {
    if (!experimentalEnabled || !readiness.allReady) {
      throw StateError('Financial cloud synchronization is disabled.');
    }
    final queue = await outbox.pending(vaultId: vaultId, limit: limit);
    var acknowledged = 0, conflicts = 0, retryLater = 0;
    for (final item in queue) {
      WaffraAtomicCommitReceipt receipt;
      try {
        receipt = await atomicPort.createIfAbsent(item);
      } catch (_) {
        // Network/transaction uncertainty must never discard a pending
        // mutation. Retrying should be safe with the same mutation ID.
        retryLater++;
        continue;
      }
      if (receipt.status == WaffraAtomicCommitStatus.conflict) {
        conflicts++;
        continue;
      }
      if (receipt.status == WaffraAtomicCommitStatus.temporarilyUnavailable) {
        retryLater++;
        continue;
      }
      final confirmed = receipt.confirmedRevision;
      if (confirmed == null ||
          WaffraEncryptedCloudOutbox.preflight(
            item: item,
            remote: confirmed,
            consentGiven: readiness.userConsented,
            identityVerified: readiness.accountOwnershipVerified,
            recoveryReady: readiness.recoveryVerified,
            atomicRemoteTransportReady: readiness.transactionalAdapterVerified,
          ) != WaffraRemoteAction.alreadyApplied) {
        retryLater++;
        continue;
      }
      try {
        await outbox.acknowledge(item: item, confirmedRemote: confirmed);
        acknowledged++;
      } catch (_) {
        // Crash/DB failure between remote transaction and local commit must
        // preserve the queued mutation for exact-idempotent replay.
        retryLater++;
      }
    }
    return WaffraSyncDryRunReport(
      pendingAttempted: queue.length, acknowledged: acknowledged,
      conflicts: conflicts, retryLater: retryLater,
    );
  }
}

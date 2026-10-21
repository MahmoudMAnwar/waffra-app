import 'legacy_financial_snapshot.dart' show WaffraLegacySnapshotInspector;
import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_ledger_projection.dart';
import 'waffra_portable_backup_v2.dart';

/// A strictly offline, opt-in restore DRY RUN against an isolated encrypted
/// SQLite sandbox. It does not read/write app SharedPreferences, receipts on
/// disk, accounts, a current user vault, or Firebase.
///
/// Caller MUST supply a newly created, disposable sandbox database. This API
/// is intentionally not wired to main.dart, startup or an import UI.
class WaffraOfflineRestoreDryRun {
  const WaffraOfflineRestoreDryRun({
    required this.sandbox,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore sandbox;
  final bool experimentalEnabled;

  Future<WaffraRestoreDryRunResult> verifyIntoSandbox({
    required String sandboxVaultId,
    required String encryptedArchive,
    required String password,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Backup restore staging is disabled by default.');
    }
    if (sandboxVaultId.trim().isEmpty ||
        sandboxVaultId.length > 128 ||
        sandboxVaultId.contains('/')) {
      throw ArgumentError('Invalid isolated restore vault.');
    }

    // Verify cryptographic authenticity, strict source keys, all receipt
    // bytes and their reference mapping BEFORE any database transaction.
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedArchive,
      password: password,
    );
    final snapshot = preview.financialSnapshot;
    final strict = WaffraLegacyPreflight.inspect(snapshot);
    final old = const WaffraLegacySnapshotInspector().inspect(snapshot);
    if (!strict.canStage || !old.canStage ||
        preview.sourceChecksum != strict.sourceSha256 ||
        preview.receiptCount != old.receiptReferences) {
      throw StateError('Financial archive preflight/parity failed.');
    }

    // Outer transaction is required: a failed relational projection should
    // roll back the staged shadow rows too in the caller's sandbox.
    return sandbox.transaction(() async {
      final staged = await sandbox.stageSnapshot(sandboxVaultId, snapshot);
      final projection = await sandbox.buildRelationalProjection(
          sandboxVaultId);
      if (staged.sourceSha256 != preview.sourceChecksum ||
          projection.sourceSha256 != preview.sourceChecksum ||
          staged.recordCount != projection.stagedSourceRecords ||
          staged.incomeMinor != projection.incomeMinor ||
          staged.expenseMinor != projection.expenseMinor ||
          staged.receiptReferences != projection.receiptReferences ||
          projection.receiptReferences != preview.receiptCount) {
        throw StateError('Encrypted sandbox import parity failed.');
      }
      return WaffraRestoreDryRunResult(
        verified: true,
        transactionCount: projection.ledgerEntries,
        receiptBytesVerified: preview.receiptCount,
        sourceChecksum: preview.sourceChecksum,
      );
    });
  }
}

class WaffraRestoreDryRunResult {
  const WaffraRestoreDryRunResult({
    required this.verified,
    required this.transactionCount,
    required this.receiptBytesVerified,
    required this.sourceChecksum,
  });

  final bool verified;
  final int transactionCount, receiptBytesVerified;
  final String sourceChecksum;

  /// Only non-sensitive summary flags are suitable for telemetry.
  Map<String, Object> get redactedDiagnostics => {
    'sandbox_archive_verified': verified,
    'has_transactions': transactionCount > 0,
    'has_verified_receipt_bytes': receiptBytesVerified > 0,
  };
}

import 'dart:convert';
import 'dart:io';

import 'waffra_disposable_recovery_journal.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_offline_restore_dry_run.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_receipt_restore_sandbox.dart';
import 'waffra_receipt_sandbox_auditor.dart';

/// Result of a complete OFFLINE and DISPOSABLE recovery dress rehearsal.
/// It is not permission to overwrite any existing user data.
class WaffraCombinedRestoreReport {
  const WaffraCombinedRestoreReport({
    required this.sourceChecksum,
    required this.transactionCount,
    required this.receiptCount,
    required this.receiptBytes,
  });

  final String sourceChecksum;
  final int transactionCount;
  final int receiptCount;
  final int receiptBytes;

  Map<String, bool> get redactedDiagnostics => {
    'isolated_financial_parity_passed': true,
    'isolated_receipt_audit_passed': true,
    'contains_receipt_files': receiptCount > 0,
  };
}

/// Chains M16 archive authentication, M19 receipt staging, M20 independent
/// receipt audit and M17 encrypted relational parity against disposable targets.
///
/// This cannot operate on existing app data: caller must supply an isolated
/// encrypted SQLite database and an EMPTY dedicated receipt sandbox folder.
/// Neither is selected automatically. There are no Firebase or UI side effects.
///
/// WARNING: This is a DRY RUN, NOT an atomic cross-resource transaction.
/// If an exception occurs, discard BOTH disposable targets. A production
/// cutover needs a durable journal and explicit rollback for DB and files.
class WaffraOfflineCombinedRestoreVerifier {
  const WaffraOfflineCombinedRestoreVerifier({
    required this.disposableStore,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore disposableStore;
  final bool experimentalEnabled;

  Future<WaffraCombinedRestoreReport> verify({
    required String sandboxVaultId,
    required String encryptedArchive,
    required String password,
    required Directory emptyReceiptSandboxDirectory,
    WaffraDisposableRecoveryJournal? journal,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Combined restoration is disabled by default.');
    }
    // Validate both destinations before any mutation. All destinations must
    // belong to the caller's isolated disposable recovery environment.
    if (sandboxVaultId.trim().isEmpty ||
        sandboxVaultId.length > 128 ||
        sandboxVaultId.contains('/') ||
        sandboxVaultId.contains('\\') ||
        sandboxVaultId == '.' ||
        sandboxVaultId == '..') {
      throw ArgumentError('Invalid restore sandbox vault ID.');
    }
    if (await FileSystemEntity.type(emptyReceiptSandboxDirectory.path,
            followLinks: false) != FileSystemEntityType.directory ||
        (await emptyReceiptSandboxDirectory
            .list(followLinks: false).toList()).isNotEmpty) {
      throw StateError('A real empty receipt sandbox directory is required.');
    }

    // Authenticate the archive and EVERY embedded receipt before touching
    // the filesystem or importing any rows.
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedArchive,
      password: password,
    );
    final rawEntries = preview.financialSnapshot['entries'];
    final entryCount = rawEntries == null
        ? 0
        : (jsonDecode(rawEntries as String) as List).length;
    if (journal != null) {
      await journal.appendVerifiedPhase(
        phase: 0,
        sourceChecksum: preview.sourceChecksum,
        entries: entryCount,
        receipts: preview.receiptCount,
      );
    }
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true,
    ).stage(
      emptySandboxDirectory: emptyReceiptSandboxDirectory,
      preview: preview,
    );
    final audited = await const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true,
    ).verify(
      sandboxDirectory: emptyReceiptSandboxDirectory,
      preview: preview,
      staged: staged,
    );

    if (journal != null) {
      await journal.appendVerifiedPhase(
        phase: 1,
        sourceChecksum: preview.sourceChecksum,
        entries: entryCount,
        receipts: preview.receiptCount,
      );
    }

    // The M17 importer re-authenticates the original encrypted archive and
    // runs finance staging + relational parity in one SQLite transaction.
    final finance = await WaffraOfflineRestoreDryRun(
      sandbox: disposableStore,
      experimentalEnabled: true,
    ).verifyIntoSandbox(
      sandboxVaultId: sandboxVaultId,
      encryptedArchive: encryptedArchive,
      password: password,
    );

    if (!finance.verified ||
        finance.sourceChecksum != preview.sourceChecksum ||
        finance.receiptBytesVerified != audited.restoredFiles ||
        finance.receiptBytesVerified != preview.receiptCount) {
      throw StateError('Combined restoration verification failed.');
    }

    if (journal != null) {
      await journal.appendVerifiedPhase(
        phase: 2,
        sourceChecksum: preview.sourceChecksum,
        entries: entryCount,
        receipts: preview.receiptCount,
      );
    }
    return WaffraCombinedRestoreReport(
      sourceChecksum: finance.sourceChecksum,
      transactionCount: finance.transactionCount,
      receiptCount: audited.restoredFiles,
      receiptBytes: audited.restoredBytes,
    );
  }
}

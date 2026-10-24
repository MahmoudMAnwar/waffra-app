import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'legacy_financial_snapshot.dart' show WaffraLegacySnapshotInspector;
import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_ledger_projection.dart';
import 'waffra_offline_receipt_path_planner.dart';
import 'waffra_portable_backup_v2.dart';

class WaffraCopiedReceiptLedgerParity {
  const WaffraCopiedReceiptLedgerParity({
    required this.ledgerEntries,
    required this.receiptCount,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int ledgerEntries;
  final int receiptCount;
  final int incomeMinor;
  final int expenseMinor;
}

/// Offline, disabled-by-default staging of a remapped archive into an
/// isolated encrypted DB. Verifies copied receipt bytes and SQL receipt rows
/// before reporting success. NO active app/legacy migration is performed.
///
/// This is not atomic across DB+filesystem and can only be used with
/// disposable, exclusively owned directories and a disposable database.
class WaffraCopiedReceiptLedgerVerifier {
  const WaffraCopiedReceiptLedgerVerifier({
    required this.disposableStore,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore disposableStore;
  final bool experimentalEnabled;

  Future<WaffraCopiedReceiptLedgerParity> verifyAndStage({
    required String disposableVaultId,
    required WaffraBackupV2Preview preview,
    required WaffraReceiptRemapPlan plan,
    required Directory copiedReceiptDirectory,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Remapped financial staging is disabled by default.');
    }
    if (disposableVaultId.trim().isEmpty ||
        disposableVaultId.length > 128 ||
        disposableVaultId == '.' || disposableVaultId == '..' ||
        disposableVaultId.contains('/') ||
        disposableVaultId.contains('\\')) {
      throw ArgumentError('Invalid disposable vault ID.');
    }
    if (await FileSystemEntity.type(copiedReceiptDirectory.path,
            followLinks: false) != FileSystemEntityType.directory) {
      throw StateError('Receipt target must be a real disposable directory.');
    }
    final origin = preview.financialSnapshot;
    final rewritten = plan.remappedSnapshot;
    final strictOrigin = WaffraLegacyPreflight.inspect(origin);
    final originFinance = const WaffraLegacySnapshotInspector().inspect(origin);
    final strictTarget = WaffraLegacyPreflight.inspect(rewritten);
    final targetFinance = const WaffraLegacySnapshotInspector().inspect(rewritten);
    if (!strictOrigin.canStage || !strictTarget.canStage ||
        !originFinance.canStage || !targetFinance.canStage ||
        strictOrigin.sourceSha256 != preview.sourceChecksum ||
        plan.sourceChecksum != preview.sourceChecksum ||
        originFinance.incomeMinor != targetFinance.incomeMinor ||
        originFinance.expenseMinor != targetFinance.expenseMinor ||
        originFinance.receiptReferences != targetFinance.receiptReferences) {
      throw StateError('Finance source/target parity failed.');
    }
    // The only change permitted by this specific step is receiptPath.
    if (origin.keys.toSet().difference(rewritten.keys.toSet()).isNotEmpty ||
        rewritten.keys.toSet().difference(origin.keys.toSet()).isNotEmpty ||
        origin.keys.any((k) => k != 'entries' &&
            jsonEncode(origin[k]) != jsonEncode(rewritten[k]))) {
      throw StateError('Non-receipt finance keys changed.');
    }
    final a = origin['entries'] == null
        ? <dynamic>[] : jsonDecode(origin['entries'] as String) as List;
    final b = rewritten['entries'] == null
        ? <dynamic>[] : jsonDecode(rewritten['entries'] as String) as List;
    if (a.length != b.length || plan.entryCount != a.length ||
        plan.receiptCount != preview.receiptCount) {
      throw StateError('Entry or receipt count changed.');
    }

    final expectedPaths = <String>{};
    final receiptsBySlot = <String, List<int>>{};
    for (final receipt in preview.receipts) {
      final slot = jsonEncode([receipt.entryId, receipt.position]);
      if (receiptsBySlot.containsKey(slot)) {
        throw StateError('Duplicate backup receipt association.');
      }
      receiptsBySlot[slot] = receipt.bytes;
    }
    for (var i = 0; i < a.length; i++) {
      final before = Map<String, dynamic>.from(a[i] as Map);
      final after = Map<String, dynamic>.from(b[i] as Map);
      final id = before['id'] as String;
      if (after['id'] != id) throw StateError('Entry identity changed.');
      final beforePaths = WaffraLegacySnapshotInspector.receiptPaths(
          before.remove('receiptPath'));
      final afterPaths = WaffraLegacySnapshotInspector.receiptPaths(
          after.remove('receiptPath'));
      if (jsonEncode(before) != jsonEncode(after) ||
          beforePaths.length != afterPaths.length) {
        throw StateError('Financial transaction content changed.');
      }
      for (var position = 0; position < afterPaths.length; position++) {
        final basename =
            '${sha256.convert(utf8.encode(jsonEncode([id, position])))}.bin';
        final exactPath =
            '${copiedReceiptDirectory.path}${Platform.pathSeparator}$basename';
        if (afterPaths[position] != exactPath ||
            !expectedPaths.add(exactPath) ||
            !receiptsBySlot.containsKey(jsonEncode([id, position]))) {
          throw StateError('Receipt path was forged or duplicated.');
        }
      }
    }
    if (expectedPaths.length != preview.receiptCount ||
        receiptsBySlot.length != preview.receiptCount) {
      throw StateError('Archive receipt association mismatch.');
    }

    Future<void> auditCopiedFiles() async {
      final listed = await copiedReceiptDirectory
          .list(followLinks: false).toList();
      if (listed.length != expectedPaths.length ||
          listed.any((entity) => !expectedPaths.contains(entity.path))) {
        throw StateError('Unexpected copied receipt files.');
      }
      for (final filePath in expectedPaths) {
        if (await FileSystemEntity.type(filePath, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('Copied receipt not a regular file.');
        }
      }
      for (final receipt in preview.receipts) {
        final basename = sha256.convert(
          utf8.encode(jsonEncode([receipt.entryId, receipt.position])));
        final path =
            '${copiedReceiptDirectory.path}${Platform.pathSeparator}$basename.bin';
        final actual = await File(path).readAsBytes();
        if (actual.length != receipt.bytes.length ||
            sha256.convert(actual) != sha256.convert(receipt.bytes)) {
          throw StateError('Copied receipt bytes changed.');
        }
      }
    }
    await auditCopiedFiles();

    // Both shadow import and relational projection share a DB transaction.
    // A failure here does NOT delete or activate the verified external files.
    return disposableStore.transaction(() async {
      final stage = await disposableStore.stageSnapshot(
        disposableVaultId, rewritten);
      final projection = await disposableStore
          .buildRelationalProjection(disposableVaultId);
      if (stage.sourceSha256 != strictTarget.sourceSha256 ||
          projection.sourceSha256 != strictTarget.sourceSha256 ||
          stage.incomeMinor != originFinance.incomeMinor ||
          stage.expenseMinor != originFinance.expenseMinor ||
          projection.incomeMinor != originFinance.incomeMinor ||
          projection.expenseMinor != originFinance.expenseMinor ||
          projection.ledgerEntries != a.length ||
          projection.receiptReferences != expectedPaths.length) {
        throw StateError('Encrypted ledger parity check failed.');
      }
      final dbReceipts = await disposableStore.customSelect(
        'SELECT legacy_absolute_path FROM entry_receipts WHERE vault_id = ?',
        variables: [Variable.withString(disposableVaultId)],
      ).get();
      if (dbReceipts.length != expectedPaths.length ||
          dbReceipts.any((r) => !expectedPaths.contains(
              r.read<String>('legacy_absolute_path')))) {
        throw StateError('SQL receipt path mapping does not match files.');
      }
      // Verify again before the DB transaction is committed.
      await auditCopiedFiles();
      return WaffraCopiedReceiptLedgerParity(
        ledgerEntries: projection.ledgerEntries,
        receiptCount: projection.receiptReferences,
        incomeMinor: projection.incomeMinor,
        expenseMinor: projection.expenseMinor,
      );
    });
  }
}

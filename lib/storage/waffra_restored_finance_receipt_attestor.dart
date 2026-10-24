import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_restored_finance_parity.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

/// SECOND independent read-only attestation after an atomic SQLCipher restore.
/// Does not switch a source pointer or remove the original backup.
class WaffraRestoredFinanceReceiptAttestor {
  const WaffraRestoredFinanceReceiptAttestor({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  Future<void> attest({
    required WaffraBackupV2Preview authenticatedArchive,
    required WaffraPortableEncryptedRestoreResult reported,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted restore attestation is not authorized.');
    }
    final actual = await WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    ).read();
    if (actual.generation != reported.encryptedGeneration ||
        reported.sourceChecksum != authenticatedArchive.sourceChecksum) {
      throw StateError('Restore checkpoint and authenticated archive disagree.');
    }
    WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: authenticatedArchive.financialSnapshot,
      restored: actual.values,
    );
    final raw = authenticatedArchive.financialSnapshot['entries'];
    final expected = raw == null ? <dynamic>[] : jsonDecode(raw as String) as List;
    final afterRaw = actual.values['entries'];
    final saved = afterRaw == null ? <dynamic>[] :
        jsonDecode(afterRaw as String) as List;
    if (saved.length != expected.length ||
        reported.transactionCount != expected.length ||
        reported.receiptCount != authenticatedArchive.receiptCount) {
      throw StateError('Restored transaction or invoice counts differ.');
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final row in saved) {
      if (row is! Map || row['id'] is! String ||
          byId.containsKey(row['id'])) {
        throw StateError('Restored transaction IDs are invalid or duplicated.');
      }
      byId[row['id'] as String] = Map<String, dynamic>.from(row);
    }
    final expectedReceipts = <String, List<WaffraReceiptBackupPart>>{};
    for (final part in authenticatedArchive.receipts) {
      expectedReceipts.putIfAbsent(part.entryId, () => []).add(part);
    }
    final receiptVault = WaffraEncryptedReceiptVault(
      store: store, experimentalEnabled: true,
    );
    var allBytes = 0, partsVerified = 0;
    for (final old in expected) {
      if (old is! Map || old['id'] is! String) {
        throw StateError('Source backup contains malformed finance row.');
      }
      final id = old['id'] as String;
      final restored = byId.remove(id);
      if (restored == null) {
        throw StateError('Restored finance row was lost.');
      }
      final original = Map<String, dynamic>.from(old);
      WaffraRestoredFinanceParity.requireExactTransactionFields(
        original: original,
        restored: restored,
      );
      final receipts = List<WaffraReceiptBackupPart>.of(
        expectedReceipts[id] ?? const <WaffraReceiptBackupPart>[],
      )..sort((a, b) => a.position.compareTo(b.position));
      final live = await receiptVault.readAll(id);
      if (live.length != receipts.length) {
        throw StateError('Restored receipt count mismatch.');
      }
      final tokens = [
        for (var i = 0; i < receipts.length; i++)
          WaffraEncryptedReceiptReference.of(id, i),
      ];
      final expectedReference = tokens.isEmpty ? null :
          tokens.length == 1 ? tokens.single : jsonEncode(tokens);
      if (restored['receiptPath'] != expectedReference) {
        throw StateError('Unsafe or missing encrypted receipt reference.');
      }
      for (var i = 0; i < receipts.length; i++) {
        final exact = live[i];
        if (receipts[i].position != i || exact.position != i ||
            sha256.convert(exact.bytes) != sha256.convert(receipts[i].bytes)) {
          throw StateError('Restored receipt bytes were not preserved.');
        }
        allBytes += exact.bytes.length;
        partsVerified++;
      }
    }
    if (byId.isNotEmpty || partsVerified != reported.receiptCount ||
        allBytes != reported.receiptBytes) {
      throw StateError('Restored financial data did not attest in full.');
    }
    for (final pair in authenticatedArchive.financialSnapshot.entries) {
      if (pair.key == 'entries' || pair.key == 'waffra_custom_goals_v1') continue;
      if (jsonEncode(actual.values[pair.key]) != jsonEncode(pair.value)) {
        throw StateError('Restored finance module differs from source.');
      }
    }
  }
}

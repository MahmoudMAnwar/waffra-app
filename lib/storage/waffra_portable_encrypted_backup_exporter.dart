import 'dart:convert';
import 'dart:io';

import 'legacy_financial_snapshot.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

/// Produces portable password-encrypted archives directly from an ALREADY
/// ACTIVATED SQLCipher source. Every referenced receipt is copied from its
/// encrypted BLOB, validated, and included in a single authenticated archive.
///
/// No individual image or decrypted financial value is uploaded to Firebase.
/// This service is opt-in and never selects a live source by itself.
class WaffraPortableEncryptedBackupExporter {
  const WaffraPortableEncryptedBackupExporter({
    required this.snapshot,
    required this.receiptVault,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final WaffraEncryptedReceiptVault receiptVault;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  final bool experimentalEnabled;

  Future<String> export({required String password}) async {
    if (!experimentalEnabled) {
      throw StateError('Verified SQLCipher backup export is not activated.');
    }
    // Keep the same native lock for dashboard, widget and receipt writes until
    // the archive is authenticated. Otherwise an edited entry could be packed
    // with a receipt from a different revision.
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory, experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      final state = await snapshot.read();
      WaffraFinanceReadView.fromEncrypted(state).requireIntegrity();
      final finance = Map<String, Object?>.from(state.values);
      final raw = finance['entries'];
      final rows = raw == null ? <dynamic>[] : jsonDecode(raw as String) as List;
      final receipts = <WaffraReceiptBackupPart>[];
      for (final rawRow in rows) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final entryId = row['id'] as String;
        final names = WaffraLegacySnapshotInspector.receiptPaths(
          row['receiptPath'],
        );
        if (names.isEmpty) {
          if (row['receiptPath'] != null &&
              row['receiptPath'] != '') {
            throw StateError('Malformed archived receipt references.');
          }
          continue;
        }
        if (names.length > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
          throw StateError('Encrypted backup has too many attached images.');
        }
        final stored = await receiptVault.readAll(entryId);
        if (stored.length != names.length) {
          throw StateError('Backup receipts and finance ledger disagree.');
        }
        for (var position = 0; position < names.length; position++) {
          if (!WaffraEncryptedReceiptReference.matches(
                names[position], entryId, position) ||
              stored[position].position != position) {
            throw StateError('Untrusted receipt file path or position.');
          }
          receipts.add(WaffraReceiptBackupPart(
            entryId: entryId,
            position: position,
            bytes: List<int>.unmodifiable(stored[position].bytes),
          ));
        }
      }

      // A dangling encrypted blob must not be omitted from a supposedly
      // complete backup. Check the entire table, not only ledger references.
      final hasBlobTable = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_receipt_blobs'",
      ).get();
      if (hasBlobTable.isNotEmpty) {
        final total = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM fresh_finance_receipt_blobs',
        ).getSingle();
        if (total.read<int>('n') != receipts.length) {
          throw StateError('Unreferenced encrypted receipt blocks export.');
        }
      } else if (receipts.isNotEmpty) {
        throw StateError('Encrypted receipt BLOB table is missing.');
      }

      // Restore custom goal suggestions from their encrypted independent
      // table. These are a separate approved field in portable V2 exports.
      final custom = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_custom_goals'",
      ).get();
      if (custom.isNotEmpty) {
        final suggestions = await snapshot.store.customSelect(
          'SELECT position,suggestion FROM fresh_finance_custom_goals '
          'ORDER BY position ASC',
        ).get();
        final values = <String>[];
        for (var i = 0; i < suggestions.length; i++) {
          if (suggestions[i].read<int>('position') != i) {
            throw StateError('Encrypted custom goal ordering is corrupt.');
          }
          values.add(suggestions[i].read<String>('suggestion'));
        }
        finance['waffra_custom_goals_v1'] = values;
      }
      return WaffraPortableBackupV2.create(
        financialSnapshot: finance,
        receipts: receipts,
        password: password,
      );
    });
  }
}

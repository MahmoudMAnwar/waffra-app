import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

class WaffraEncryptedReceiptTransactionResult {
  const WaffraEncryptedReceiptTransactionResult({
    required this.entryId,
    required this.receiptCount,
    required this.receiptBytes,
    required this.generation,
  });

  final String entryId;
  final int receiptCount;
  final int receiptBytes;
  final int generation;
}

/// Candidate atomic save boundary for a NEW finance entry and its pictures.
///
/// One native app/widget lock + ONE SQLCipher transaction persist the
/// normalized entry, encrypted receipt BLOBs, finance screen snapshot and
/// optional SMS dedupe hash together. Any failure rolls back ALL these rows.
///
/// Caller must supply raw image BYTES from the image picker, not a copied
/// public file path. Existing main.dart's plain-file saveReceipt stays on
/// guarded legacy until source cutover and full UI receipt-preview routing.
///
/// Intentionally disabled unless an independently verified source coordinator
/// explicitly enables the encrypted runtime. No key, DB or source is created.
class WaffraAtomicEncryptedReceiptTransactionWriter {
  const WaffraAtomicEncryptedReceiptTransactionWriter({
    required this.snapshot,
    required this.receiptVault,
    required this.writerDirectory,
    this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final WaffraEncryptedReceiptVault receiptVault;
  final Directory writerDirectory;
  final Future<void> Function()? verifySourceUnderLock;
  final bool experimentalEnabled;

  Future<WaffraEncryptedReceiptTransactionResult> save({
    required Map<String, Object?> record,
    required List<Uint8List> receiptImages,
    required bool userConfirmed,
    String? smsHash,
  }) async {
    if (!experimentalEnabled || verifySourceUnderLock == null) {
      throw StateError('Verified encrypted receipt writing is not enabled.');
    }
    if (!identical(snapshot.store, receiptVault.store)) {
      throw StateError('Finance and encrypted receipt stores differ.');
    }
    if (!userConfirmed) {
      throw StateError('User must confirm the financial transaction.');
    }
    const permitted = {
      'id', 'title', 'category', 'amount', 'income', 'date', 'receiptPath',
    };
    if (record.keys.any((key) => !permitted.contains(key)) ||
        record['receiptPath'] != null && record['receiptPath'] != '' ||
        record['id'] is! String ||
        (record['id'] as String).trim().isEmpty ||
        (record['id'] as String).length > 128 ||
        record['title'] is! String ||
        (record['title'] as String).trim().isEmpty ||
        (record['title'] as String).length > 2048 ||
        record['category'] is! String ||
        (record['category'] as String).trim().isEmpty ||
        (record['category'] as String).length > 256 ||
        record['amount'] is! num ||
        !WaffraLegacyPreflight.canRepresentHalalas(record['amount'] as num) ||
        (record['amount'] as num) <= 0 ||
        record['income'] is! bool ||
        record['date'] is! String ||
        DateTime.tryParse(record['date'] as String) == null) {
      throw ArgumentError('Untrusted financial entry or legacy receipt path.');
    }
    if (smsHash != null &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(smsHash)) {
      throw ArgumentError('Only SHA-256 bank SMS fingerprints are accepted.');
    }
    if (receiptImages.isEmpty ||
        receiptImages.length > WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
        receiptImages.any((bytes) =>
            bytes.isEmpty ||
            bytes.length > WaffraEncryptedReceiptVault.maxReceiptBytes)) {
      throw ArgumentError('A valid encrypted receipt batch is required.');
    }
    final count = receiptImages.length;
    // Snapshot mutable picker memory before ANY await.
    final images = receiptImages
        .map((bytes) => Uint8List.fromList(bytes)).toList(growable: false);
    final totalBytes = images.fold<int>(0, (n, bytes) => n + bytes.length);
    if (totalBytes > 60 * 1024 * 1024) {
      throw ArgumentError('Total receipt batch is too large.');
    }
    final entryId = record['id'] as String;
    final tokens = List<String>.generate(
      count, (position) =>
          WaffraEncryptedReceiptReference.of(entryId, position),
      growable: false,
    );
    final committedRecord = Map<String, Object?>.from(record);
    committedRecord['receiptPath'] =
        count == 1 ? tokens.single : jsonEncode(tokens);
    if (!WaffraLegacyPreflight.inspect({
      'entries': jsonEncode([committedRecord]),
    }).canStage) {
      throw ArgumentError('Malformed financial entry for encrypted storage.');
    }

    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock!.call();
      return snapshot.store.transaction(() async {
        final state = await snapshot.read();
        final next = Map<String, Object?>.from(state.values);
        final decoded = jsonDecode(next['entries'] as String? ?? '[]');
        if (decoded is! List || decoded.any((row) => row is! Map)) {
          throw StateError('Existing encrypted ledger is corrupt.');
        }
        final oldEntries = decoded.cast<Map>();
        if (oldEntries.any((row) => row['id'] == entryId)) {
          throw StateError('Duplicate finance entry ID.');
        }
        // A direct SQL write from an older app must not silently exist outside
        // the canonical snapshot. Refuse a split-brain vault before mutation.
        final tableCount = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM fresh_finance_entries',
        ).getSingle();
        if (tableCount.read<int>('n') != oldEntries.length) {
          throw StateError('Encrypted SQL ledger differs from screen snapshot.');
        }

        final hashes = Set<String>.from(
          next['waffra_sms_hashes_v1'] as List<String>? ?? const [],
        );
        if (smsHash != null && hashes.contains(smsHash)) {
          throw StateError('This bank transaction was already confirmed.');
        }
        // The caller can modify the picker/form map while the native lock
        // and source witness are awaited. Commit ONLY the immutable,
        // pre-confirmation snapshot into both normalized SQL and ledger JSON.
        // Otherwise the two sources can disagree despite one SQL transaction.
        final amountMinor = ((committedRecord['amount'] as num) * 100).round();
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES(?,?,?,?,?,?,?,?)',
          [
            entryId, committedRecord['title'], committedRecord['category'],
            amountMinor, committedRecord['income'] == true ? 1 : 0,
            committedRecord['date'], 0, jsonEncode(committedRecord),
          ],
        );
        // Nested drift transactions are savepoints on the SAME SQLCipher DB.
        // The parent transaction owns the final commit.
        await receiptVault.attachNewBatch(entryId: entryId, images: images);
        final exact = await receiptVault.readAll(entryId);
        if (exact.length != count ||
            exact.fold<int>(0, (sum, item) => sum + item.bytes.length) !=
                totalBytes) {
          throw StateError('Receipt bytes did not match the confirmed batch.');
        }
        for (var index = 0; index < count; index++) {
          if (exact[index].position != index ||
              sha256.convert(exact[index].bytes) !=
                  sha256.convert(images[index])) {
            throw StateError('Encrypted receipt image content changed.');
          }
        }
        if (smsHash != null) {
          hashes.add(smsHash);
          next['waffra_sms_hashes_v1'] = hashes.toList()..sort();
        }
        next['entries'] = jsonEncode([...oldEntries, committedRecord]);
        final committed = await snapshot.commit(
          expectedGeneration: state.generation,
          fullFinanceSnapshot: next,
        );
        // Both receiptVault.readAll and snapshot.commit verified the same
        // transaction; the enclosing SQLCipher commit is still pending.
        return WaffraEncryptedReceiptTransactionResult(
          entryId: entryId,
          receiptCount: count,
          receiptBytes: totalBytes,
          generation: committed.generation,
        );
      });
    });
  }
}

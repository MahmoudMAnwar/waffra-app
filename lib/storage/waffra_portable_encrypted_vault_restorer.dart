import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';
import 'waffra_portable_backup_v2.dart';

/// Opaque local-only receipt reference. No device-specific absolute path is
/// copied from the old phone into a restored transaction's live JSON.
class WaffraEncryptedReceiptReference {
  const WaffraEncryptedReceiptReference._();

  static String of(String entryId, int position) {
    if (entryId.trim().isEmpty || position < 0) {
      throw ArgumentError('Invalid receipt association.');
    }
    final owner = sha256.convert(utf8.encode(entryId)).toString();
    return 'waffra-receipt://$owner/$position';
  }

  static bool matches(String value, String entryId, int position) =>
      value == of(entryId, position);
}

class WaffraPortableEncryptedRestoreResult {
  const WaffraPortableEncryptedRestoreResult({
    required this.sourceChecksum,
    required this.encryptedGeneration,
    required this.transactionCount,
    required this.receiptCount,
    required this.receiptBytes,
  });
  final String sourceChecksum;
  final int encryptedGeneration;
  final int transactionCount;
  final int receiptCount;
  final int receiptBytes;
}

/// Offline restore of a PASSWORD AUTHENTICATED portable archive into an
/// exclusively owned EMPTY SQLCipher vault. ALL financial collections,
/// transaction rows and attachment bytes are committed in ONE SQLite tx.
///
/// This component does not open a production database, activate a source
/// selector, touch SharedPreferences or attempt to restore account details.
/// A future production cutover must supply verified secure-key persistence,
/// app/widget routing, UI receipt resolution and a recovery journal.
class WaffraPortableEncryptedVaultRestorer {
  const WaffraPortableEncryptedVaultRestorer({
    required this.disposableStore,
    this.experimentalEnabled = false,
  });
  final WaffraEncryptedStore disposableStore;
  final bool experimentalEnabled;

  Future<WaffraPortableEncryptedRestoreResult> restore({
    required String encryptedArchive,
    required String password,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted portable restore is disabled by default.');
    }
    // Authenticate the archive, validate all financial fields and verify
    // EVERY byte/hash/owner of receipts before mutating any SQL rows.
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedArchive,
      password: password,
    );
    final rawEntries = preview.financialSnapshot['entries'];
    final rows = rawEntries == null
        ? <dynamic>[]
        : jsonDecode(rawEntries as String) as List<dynamic>;
    final imagesByEntry = <String, List<WaffraReceiptBackupPart>>{};
    for (final receipt in preview.receipts) {
      imagesByEntry.putIfAbsent(receipt.entryId,
          () => <WaffraReceiptBackupPart>[]).add(receipt);
    }
    final transformed = <Map<String, dynamic>>[];
    var receiptBytes = 0;
    for (final original in rows) {
      final row = Map<String, dynamic>.from(original as Map);
      final id = row['id'] as String;
      final parts = imagesByEntry[id] ?? <WaffraReceiptBackupPart>[];
      parts.sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].position != i) {
          throw StateError('Receipt slot missing in archive.');
        }
        receiptBytes += parts[i].bytes.length;
      }
      if (parts.isNotEmpty) {
        final tokens = List<String>.generate(
          parts.length, (i) => WaffraEncryptedReceiptReference.of(id, i),
        );
        row['receiptPath'] =
            tokens.length == 1 ? tokens.single : jsonEncode(tokens);
      } else {
        row['receiptPath'] = null;
      }
      transformed.add(row);
    }
    // Preserve all other finance arrays, money and SMS dedupe states exactly.
    // The custom-goal suggestion key is nonfinancial and intentionally not
    // part of the encrypted finance snapshot schema.
    final finance = <String, Object?>{
      for (final key in WaffraLegacyPreflight.allKeys)
        if (preview.financialSnapshot.containsKey(key))
          key: preview.financialSnapshot[key],
      if (rawEntries != null) 'entries': jsonEncode(transformed),
    };
    if (!WaffraLegacyPreflight.inspect(finance).canStage) {
      throw StateError('Remapped SQLCipher restore snapshot failed preflight.');
    }

    return disposableStore.transaction(() async {
      await WaffraFreshEncryptedVaultBootstrap(
        store: disposableStore, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: disposableStore, experimentalEnabled: true,
      );
      final zero = await snapshot.initializeEmpty();
      if (zero.generation != 0 || zero.values.isNotEmpty) {
        throw StateError('Target already has finance; refusing overwrite.');
      }
      final priorRows = await disposableStore.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_entries',
      ).getSingle();
      if (priorRows.read<int>('n') != 0) {
        throw StateError('Target ledger is not empty.');
      }

      // This table uses the same layout as WaffraEncryptedReceiptVault.
      await disposableStore.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_receipt_blobs(
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_name TEXT NOT NULL UNIQUE,
  content_sha256 TEXT NOT NULL,
  content_bytes INTEGER NOT NULL CHECK(content_bytes > 0),
  encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id,position)
)''');
      // Custom goal suggestions exist in legacy exports but are not part
      // of the strict finance-key snapshot; preserve them separately rather
      // than silently dropping user data during a portable restore.
      final suggestions = preview.financialSnapshot['waffra_custom_goals_v1'];
      await disposableStore.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_custom_goals(
  position INTEGER PRIMARY KEY CHECK(position >= 0),
  suggestion TEXT NOT NULL
)''');
      if (suggestions is List<String>) {
        for (var i = 0; i < suggestions.length; i++) {
          await disposableStore.customStatement(
            'INSERT INTO fresh_finance_custom_goals(position,suggestion) '
            'VALUES (?,?)', [i, suggestions[i]],
          );
        }
      }
      var incomeMinor = 0;
      var expenseMinor = 0;
      for (final row in transformed) {
        final id = row['id'] as String;
        final minor = ((row['amount'] as num) * 100).round();
        final isIncome = row['income'] as bool;
        final parts = imagesByEntry[id] ?? const <WaffraReceiptBackupPart>[];
        await disposableStore.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
          [id, row['title'], row['category'], minor, isIncome ? 1 : 0,
           row['date'], parts.length, jsonEncode(row)],
        );
        if (isIncome) { incomeMinor += minor; }
        else { expenseMinor += minor; }
        for (final part in parts) {
          final captured = Uint8List.fromList(part.bytes);
          final name = sha256.convert(
            utf8.encode(jsonEncode([id, part.position])),
          ).toString();
          await disposableStore.customStatement(
            'INSERT INTO fresh_finance_receipt_blobs '
            '(entry_id,position,safe_name,content_sha256,content_bytes,'
            'encrypted_blob) VALUES (?,?,?,?,?,?)',
            [id, part.position, '$name.bin',
             sha256.convert(captured).toString(), captured.length, captured],
          );
        }
      }
      final committed = await snapshot.commit(
        expectedGeneration: 0, fullFinanceSnapshot: finance,
      );
      final actual = await snapshot.read();
      if (actual.generation != 1 || actual.digest != committed.digest) {
        throw StateError('Encrypted financial snapshot failed round trip.');
      }
      final totals = await disposableStore.customSelect(
        'SELECT count(*) AS n, '
        'COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0) AS inc,'
        'COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0) AS exp'
        ' FROM fresh_finance_entries',
      ).getSingle();
      if (totals.read<int>('n') != transformed.length ||
          totals.read<int>('inc') != incomeMinor ||
          totals.read<int>('exp') != expenseMinor) {
        throw StateError('Encrypted ledger totals mismatch.');
      }
      final receiptVault = WaffraEncryptedReceiptVault(
        store: disposableStore, experimentalEnabled: true,
      );
      var verifiedParts = 0;
      for (final entry in imagesByEntry.entries) {
        final exact = await receiptVault.readAll(entry.key);
        if (exact.length != entry.value.length) {
          throw StateError('Encrypted receipts have missing slots.');
        }
        for (var i = 0; i < exact.length; i++) {
          if (exact[i].position != i ||
              sha256.convert(exact[i].bytes) !=
                  sha256.convert(entry.value[i].bytes)) {
            throw StateError('Encrypted receipt bytes mismatch.');
          }
          verifiedParts++;
        }
      }
      if (verifiedParts != preview.receiptCount) {
        throw StateError('Encrypted receipt count mismatch.');
      }
      return WaffraPortableEncryptedRestoreResult(
        sourceChecksum: preview.sourceChecksum,
        encryptedGeneration: committed.generation,
        transactionCount: transformed.length,
        receiptCount: verifiedParts,
        receiptBytes: receiptBytes,
      );
    });
  }
}

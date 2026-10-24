import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_module_projection_guard.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';
import 'waffra_restored_finance_parity.dart';

class WaffraEncryptedFullResetResult {
  const WaffraEncryptedFullResetResult({
    required this.previousGeneration,
    required this.newGeneration,
    required this.previousDigest,
    required this.resetDigest,
    required this.transactionsRemoved,
    required this.receiptImagesRemoved,
  });

  final int previousGeneration;
  final int newGeneration;
  final String previousDigest;
  final String resetDigest;
  final int transactionsRemoved;
  final int receiptImagesRemoved;
}

/// Standalone synthetic SQLCipher full-finance reset candidate.
///
/// There is NO production Home/Widget callsite. An independently approved
/// activated finance source, fresh immutable source snapshot and existing
/// password-encrypted external backup are mandatory BEFORE any deletion.
///
/// This only resets finance inside its original SQLCipher vault. It does NOT
/// delete identity credentials, cloud records, external backups or OS keys.
class WaffraEncryptedFullFinanceReset {
  const WaffraEncryptedFullFinanceReset({
    required this.snapshot,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  static const confirmation = 'RESET_WAFFRA_FINANCE';

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  final bool experimentalEnabled;

  static const _knownTables = <String>{
    'fresh_finance_meta',
    'fresh_finance_snapshot_state',
    'fresh_finance_entries',
    'fresh_finance_categories',
    'fresh_finance_goals',
    'fresh_finance_recurring',
    'fresh_finance_receipts',
    'fresh_finance_receipt_blobs',
    'fresh_finance_receipt_recycle',
    'fresh_finance_receipt_recycle_blobs',
    'fresh_finance_transaction_recycle',
    'fresh_finance_transaction_recycle_blobs',
    'fresh_finance_transaction_recycle_clock',
    'fresh_finance_module_recycle',
    'fresh_finance_custom_goals',
    'fresh_finance_sms_hashes',
    'fresh_finance_settings',
  };

  static const _recoveryTables = <String>[
    'fresh_finance_receipt_recycle',
    'fresh_finance_receipt_recycle_blobs',
    'fresh_finance_transaction_recycle',
    'fresh_finance_transaction_recycle_blobs',
    'fresh_finance_module_recycle',
  ];

  static const _erasedTables = <String>[
    'fresh_finance_receipt_blobs',
    'fresh_finance_receipts',
    'fresh_finance_sms_hashes',
    'fresh_finance_custom_goals',
    'fresh_finance_settings',
    'fresh_finance_recurring',
    'fresh_finance_goals',
    'fresh_finance_categories',
    'fresh_finance_entries',
  ];

  Future<Set<String>> _tables() async {
    final sql = await snapshot.store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get();
    final found = sql.map((x) => x.read<String>('name')).toSet();
    final unknown = found.where((name) =>
        name.startsWith('fresh_finance_') && !_knownTables.contains(name));
    if (unknown.isNotEmpty) {
      throw StateError('Unknown financial SQL table; reset refused.');
    }
    if (!_erasedTables.where((name) =>
        name != 'fresh_finance_receipt_blobs').every(found.contains)) {
      throw StateError('Encrypted finance typed tables are missing.');
    }
    return found;
  }

  Future<int> _count(String table) async {
    final row = await snapshot.store.customSelect(
      'SELECT count(*) AS n FROM ' + table,
    ).getSingle();
    return row.read<int>('n');
  }

  static List<Map<String, dynamic>> _ledger(String? raw) {
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) {
      throw StateError('Reset source ledger is malformed.');
    }
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          !seen.add(item['id'] as String)) {
        throw StateError('Reset source has missing or duplicate transactions.');
      }
      result.add(Map<String, dynamic>.from(item));
    }
    return result;
  }

  static int _receiptSlots(Object? reference) {
    if (reference == null || reference == '') return 0;
    if (reference is! String) {
      throw StateError('Encrypted receipt association is malformed.');
    }
    if (!reference.startsWith('[')) return 1;
    final refs = jsonDecode(reference);
    if (refs is! List || refs.any((x) => x is! String)) {
      throw StateError('Encrypted receipt association list is malformed.');
    }
    return refs.length;
  }

  static void _requireSameBackupFinance({
    required Map<String, Object?> expected,
    required Map<String, Object?> backedUp,
  }) {
    WaffraRestoredFinanceParity.requireExactFinanceKeys(
      archive: backedUp, restored: expected,
    );
    for (final entry in expected.entries) {
      if (!backedUp.containsKey(entry.key) ||
          jsonEncode(backedUp[entry.key]) != jsonEncode(entry.value)) {
        throw StateError('Authenticated backup does not match active finance.');
      }
    }
  }

  Future<void> _verifyCurrentTypedLedger(
    List<Map<String, dynamic>> records,
  ) async {
    final rows = await snapshot.store.customSelect(
      'SELECT entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,receipt_count,source_json FROM fresh_finance_entries',
    ).get();
    if (rows.length != records.length) {
      throw StateError('Encrypted typed ledger row count differs.');
    }
    final known = <String, Map<String, dynamic>>{
      for (final row in records) row['id'] as String: row,
    };
    for (final row in rows) {
      final id = row.read<String>('entry_id');
      final expected = known[id];
      final amount = expected?['amount'];
      if (expected == null ||
          amount is! num ||
          !WaffraLegacyPreflight.canRepresentHalalas(amount) ||
          expected['income'] is! bool ||
          expected['title'] != row.read<String>('title') ||
          expected['category'] != row.read<String>('category_snapshot') ||
          (amount * 100).round() != row.read<int>('amount_minor') ||
          (expected['income'] == true ? 1 : 0) != row.read<int>('is_income') ||
          expected['date'] != row.read<String>('occurred_iso') ||
          row.read<int>('receipt_count') != _receiptSlots(expected['receiptPath']) ||
          jsonEncode(expected) !=
              jsonEncode(jsonDecode(row.read<String>('source_json')))) {
        throw StateError('Typed SQL money and canonical ledger disagree.');
      }
    }
  }

  Future<int> _verifyExactLiveReceipts({
    required List<Map<String, dynamic>> records,
    required WaffraBackupV2Preview archive,
    required Set<String> tables,
  }) async {
    final backupById = <String, List<WaffraReceiptBackupPart>>{};
    for (final part in archive.receipts) {
      backupById.putIfAbsent(part.entryId, () => []).add(part);
    }
    final vault = WaffraEncryptedReceiptVault(
      store: snapshot.store, experimentalEnabled: true,
    );
    var total = 0;
    for (final record in records) {
      final id = record['id'] as String;
      final parts = backupById.remove(id) ?? <WaffraReceiptBackupPart>[];
      parts.sort((a, b) => a.position.compareTo(b.position));
      final source = await vault.readAll(id);
      if (source.length != parts.length) {
        throw StateError('Original invoice count differs from external backup.');
      }
      final expectedRefs = <String>[
        for (var i = 0; i < parts.length; i++)
          WaffraEncryptedReceiptReference.of(id, i),
      ];
      final originalRef = record['receiptPath'];
      final requiredRef = expectedRefs.isEmpty
          ? null
          : expectedRefs.length == 1
              ? expectedRefs.single
              : jsonEncode(expectedRefs);
      if (originalRef != requiredRef) {
        throw StateError('Invoice owner/path differs before full reset.');
      }
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].position != i || source[i].position != i ||
            sha256.convert(source[i].bytes) !=
                sha256.convert(parts[i].bytes)) {
          throw StateError('Invoice SHA differs from authenticated backup.');
        }
        total++;
      }
    }
    if (backupById.isNotEmpty || total != archive.receiptCount) {
      throw StateError('Missing/extra invoice backup references.');
    }
    if (tables.contains('fresh_finance_receipt_blobs')) {
      if (await _count('fresh_finance_receipt_blobs') != total) {
        throw StateError('Orphan encrypted receipt would be lost.');
      }
    } else if (total != 0) {
      throw StateError('Encrypted receipt table is missing.');
    }
    return total;
  }

  Future<void> _requireNoRecoveryHistory(
    Map<String, Object?> values,
    Set<String> tables,
  ) async {
    for (final key in const <String>[
      'waffra_deleted_categories_v1',
      'waffra_deleted_goals_v1',
      'waffra_deleted_recurring_v1',
    ]) {
      final raw = values[key];
      if (raw == null) continue;
      final decoded = raw is String ? jsonDecode(raw) : null;
      if (decoded is! List || decoded.isNotEmpty) {
        throw StateError('Recoverable deleted modules require separate backup.');
      }
    }
    for (final table in _recoveryTables) {
      if (tables.contains(table) && await _count(table) > 0) {
        throw StateError('Recoverable deleted receipt/transaction would be lost.');
      }
    }
    if (await _count('fresh_finance_receipts') > 0) {
      throw StateError('Unexported legacy receipt references block full reset.');
    }
  }

  Future<WaffraEncryptedFullResetResult> reset({
    required WaffraFinanceSnapshotState baseline,
    required String encryptedBackup,
    required String backupPassword,
    required String confirmationPhrase,
    required bool userConfirmed,
    required bool biometricVerified,
    required bool externalBackupSaved,
  }) async {
    if (!experimentalEnabled || !snapshot.experimentalEnabled ||
        !userConfirmed || !biometricVerified || !externalBackupSaved ||
        confirmationPhrase != confirmation) {
      throw StateError('Verified and explicit irreversible reset is required.');
    }
    if (backupPassword.length < 12 || backupPassword.length > 4096) {
      throw ArgumentError('External encrypted backup password is invalid.');
    }

    // Authenticate entire archive outside the native lock. This never
    // authorizes deletion by itself; archive must be CURRENT under that lock.
    final backup = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encryptedBackup, password: backupPassword,
    );

    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        WaffraFinanceReadView.fromEncrypted(current).requireIntegrity();
        if (current.generation != baseline.generation ||
            current.digest != baseline.digest) {
          throw StateError('Source changed after verified reset confirmation.');
        }
        if (WaffraLegacyPreflight.inspect(current.values).sourceSha256 !=
            backup.sourceChecksum) {
          throw StateError('External backup is not from the current finance.');
        }
        _requireSameBackupFinance(
          expected: current.values, backedUp: backup.financialSnapshot,
        );
        final tables = await _tables();
        await _requireNoRecoveryHistory(current.values, tables);

        for (final key in const <String>[
          'waffra_categories_v24', 'waffra_goals_v24',
          'waffra_recurring_v24',
        ]) {
          await WaffraEncryptedModuleProjectionGuard.reconcile(
            store: snapshot.store, key: key,
            previousJson: current.values[key] as String?,
            updatedJson: current.values[key] as String?,
          );
        }
        // SMS deduplication hashes are separately typed financial history.
        final originalHashes =
            current.values['waffra_sms_hashes_v1'] as List<String>? ??
                const <String>[];
        final shaRows = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes',
        ).get();
        final sqlHashes = shaRows.map((x) =>
            x.read<String>('message_hash')).toSet();
        if (sqlHashes.length != shaRows.length ||
            sqlHashes.length != originalHashes.length ||
            !sqlHashes.containsAll(originalHashes)) {
          throw StateError('SMS hash projection differs from saved finance.');
        }
        // Financial settings with no authenticated typed backup witness are
        // NOT silently erased by this deliberately narrow reset candidate.
        if (await _count('fresh_finance_settings') != 0) {
          throw StateError('Unattested finance settings block full reset.');
        }
        final entries = _ledger(current.values['entries'] as String?);
        await _verifyCurrentTypedLedger(entries);
        final receiptCount = await _verifyExactLiveReceipts(
          records: entries, archive: backup, tables: tables,
        );
        final custom = await snapshot.store.customSelect(
          'SELECT position,suggestion FROM fresh_finance_custom_goals '
          'ORDER BY position',
        ).get();
        final backedSuggestions = backup.financialSnapshot['waffra_custom_goals_v1'];
        final savedNames = <String>[];
        for (var i = 0; i < custom.length; i++) {
          if (custom[i].read<int>('position') != i) {
            throw StateError('Custom goal ordering is inconsistent.');
          }
          savedNames.add(custom[i].read<String>('suggestion'));
        }
        if ((backedSuggestions == null && savedNames.isNotEmpty) ||
            (backedSuggestions != null &&
             jsonEncode(backedSuggestions) != jsonEncode(savedNames))) {
          throw StateError('Custom goal catalog is not fully backed up.');
        }

        for (final table in _erasedTables) {
          if (!tables.contains(table)) continue;
          await snapshot.store.customStatement('DELETE FROM ' + table);
        }
        // Preserve source generation and cryptographic key continuity.
        // Clearing SQL rows is not equivalent to deleting an account.
        final cleared = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
        );
        for (final table in _erasedTables) {
          if (tables.contains(table) && await _count(table) != 0) {
            throw StateError('Full finance reset left a typed SQL record.');
          }
        }
        if (_ledger(cleared.values['entries'] as String?).isNotEmpty ||
            cleared.generation != current.generation + 1) {
          throw StateError('Full reset canonical finance revision differs.');
        }
        return WaffraEncryptedFullResetResult(
          previousGeneration: current.generation,
          newGeneration: cleared.generation,
          previousDigest: current.digest,
          resetDigest: cleared.digest,
          transactionsRemoved: entries.length,
          receiptImagesRemoved: receiptCount,
        );
      });
    });
  }
}

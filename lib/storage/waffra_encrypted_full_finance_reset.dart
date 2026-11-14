import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_fresh_finance_domain_schema.dart';
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
/// The SQLCipher commit succeeded, but an authenticated external receipt file
/// still requires safe deletion. Never describe this state as a rolled-back reset.
class WaffraReceiptCleanupPending implements Exception {
  const WaffraReceiptCleanupPending();
  @override
  String toString() => 'Encrypted reset committed; receipt cleanup pending.';
}

class WaffraEncryptedFullFinanceReset {
  const WaffraEncryptedFullFinanceReset({
    required this.snapshot,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.legacyReceiptsDirectory,
    this.experimentalEnabled = false,
  });

  static const confirmation = 'RESET_WAFFRA_FINANCE';

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  /// Only app-owned Documents/receipts, never an arbitrary device directory.
  final Directory? legacyReceiptsDirectory;
  final bool experimentalEnabled;

  static const _knownTables = <String>{
    'fresh_finance_meta',
    // Source activation checkpoint is NEVER erased by financial reset.
    'fresh_finance_cutover_checkpoint',
    'fresh_finance_snapshot_state',
    'fresh_finance_entries',
    'fresh_finance_categories',
    'fresh_finance_goals',
    'fresh_finance_recurring',
    'fresh_finance_receipts',
    'fresh_finance_reset_receipt_cleanup',
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
    'fresh_finance_domain_revision',
    ...WaffraFreshFinanceDomainSchema.domainTables,
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
    // Domain tables are not yet covered by portable encrypted backup/restore.
    // The reset must REFUSE to erase old records while leaving referenced
    // budget/goal/project/subscription/AI history orphaned or unbacked-up.
    // Once parity covers these rows, implement child-first verified deletion.
    for (final table in WaffraFreshFinanceDomainSchema.domainTables) {
      if (found.contains(table) && await _count(table) != 0) {
        throw StateError('Domain finance data needs verified backup/reset support.');
      }
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

  // M644: owner-authorized immediate biometric reset. No external backup is
  // mandatory; unlike the historical backup-matched variant, this path must
  // also erase account and domain projections in the SAME SQLCipher commit.
  // A missing/unrecognized SQL table refuses the operation before any write.
  static const _biometricKnownTables = <String>{
    ..._knownTables,
    'fresh_finance_money_accounts',
    'fresh_finance_account_entry_links',
    'fresh_finance_internal_transfers',
    'fresh_finance_account_revision',
    'fresh_finance_goal_account_sources',
    'fresh_finance_recurring_account_defaults',
    'fresh_finance_account_sms_suffixes',
    'fresh_finance_account_context_revision',
    'fresh_finance_account_details',
    'fresh_finance_account_details_revision',
    'fresh_finance_custom_account_subtypes',
    'fresh_finance_custom_account_subtypes_revision',
  };
  static const _biometricPreservedTables = <String>{
    'fresh_finance_meta',
    'fresh_finance_cutover_checkpoint',
    'fresh_finance_snapshot_state',
    'fresh_finance_reset_receipt_cleanup',
    'fresh_finance_domain_revision',
    'fresh_finance_account_revision',
    'fresh_finance_account_context_revision',
    'fresh_finance_account_details_revision',
    'fresh_finance_custom_account_subtypes_revision',
  };

  static const String _receiptCleanupTable =
      'fresh_finance_reset_receipt_cleanup';

  static List<String> _receiptReferences(Object? raw) {
    if (raw == null || raw == '') return const <String>[];
    if (raw is! String) throw StateError('Invalid receipt reference type.');
    final parsed = raw.startsWith('[') ? jsonDecode(raw) : <dynamic>[raw];
    if (parsed is! List || parsed.isEmpty ||
        parsed.any((part) => part is! String || part.isEmpty)) {
      throw StateError('Malformed receipt references.');
    }
    return List<String>.unmodifiable(parsed.cast<String>());
  }

  Future<String> _trustedReceiptRoot() async {
    final root = legacyReceiptsDirectory;
    if (root == null || !await root.exists()) {
      throw StateError('No verified local receipt directory.');
    }
    final canonical = await root.resolveSymbolicLinks();
    if (canonical == Platform.pathSeparator) {
      throw StateError('Device root cannot be a receipt directory.');
    }
    return canonical;
  }

  Future<String> _verifiedOwnedFilePath(String path, String root) async {
    final file = File(path);
    if (!file.isAbsolute ||
        await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.parent.resolveSymbolicLinks() != root) {
      throw StateError('Receipt is not an app-owned regular file.');
    }
    return file.resolveSymbolicLinks();
  }

  Future<String> _verifiedReceiptDigest(String path) async {
    final file = File(path);
    final before = await file.stat();
    if (before.size < 1 ||
        before.size > WaffraEncryptedReceiptVault.maxReceiptBytes) {
      throw StateError('External receipt is outside safe image limits.');
    }
    final bytes = await file.readAsBytes();
    final after = await file.stat();
    if (bytes.length != before.size || after.size != before.size ||
        after.modified != before.modified) {
      throw StateError('External receipt changed during verification.');
    }
    return sha256.convert(bytes).toString();
  }

  /// Retry an interrupted post-commit filesystem purge using the durable
  /// encrypted journal. This may be called during source-attested startup.
  /// The journal is written in the SAME SQL transaction as the ledger reset;
  /// no file is touched until that transaction has committed successfully.
  Future<void> resumePendingExternalReceiptCleanup() =>
      WaffraExperimentalWriterGate(
        disposableDirectory: writerDirectory, experimentalEnabled: true,
      ).withExclusiveAccess(() async {
        await verifySourceUnderLock();
        await _deletePendingExternalReceipts();
      });

  Future<void> _deletePendingExternalReceipts() async {
    final exists = await snapshot.store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      variables: [Variable.withString(_receiptCleanupTable)],
    ).get();
    if (exists.isEmpty) return;
    final rows = await snapshot.store.customSelect(
      'SELECT path,sha256_hex FROM ' + _receiptCleanupTable + ' ORDER BY path',
    ).get();
    if (rows.isEmpty) return;
    try {
      final root = await _trustedReceiptRoot();
      final pending = <String, bool>{};
      // Prove ALL files before removing the first; a tampered file causes
      // no new deletion and the encrypted journal remains available.
      for (final row in rows) {
        final path = row.read<String>('path');
        final digest = row.read<String>('sha256_hex');
        final file = File(path);
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          if (!file.isAbsolute ||
              await file.parent.resolveSymbolicLinks() != root) {
            throw StateError('Missing receipt path escaped app-owned folder.');
          }
          pending[path] = false; // Deleted before interruption.
          continue;
        }
        final actual = await _verifiedOwnedFilePath(path, root);
        if (actual != path ||
            await _verifiedReceiptDigest(path) != digest) {
          throw StateError('Pending receipt hash or path has changed.');
        }
        pending[path] = true;
      }
      for (final row in rows) {
        final path = row.read<String>('path');
        if (pending[path] == true) {
          final actual = await _verifiedOwnedFilePath(path, root);
          if (actual != path ||
              await _verifiedReceiptDigest(path) !=
                  row.read<String>('sha256_hex')) {
            throw StateError('Receipt changed immediately before removal.');
          }
          await File(path).delete();
        }
        // On a crash between File.delete and this SQL update, retry sees
        // the missing expected file and removes only the matching journal row.
        await snapshot.store.customStatement(
          'DELETE FROM ' + _receiptCleanupTable + ' WHERE path=?',
          [path],
        );
      }
    } catch (_) {
      throw const WaffraReceiptCleanupPending();
    }
  }

  Future<WaffraEncryptedFullResetResult> resetAfterBiometric({
    required WaffraFinanceSnapshotState baseline,
    required bool userConfirmed,
    required bool biometricVerified,
  }) async {
    if (!experimentalEnabled || !snapshot.experimentalEnabled ||
        !userConfirmed || !biometricVerified) {
      throw StateError('An explicitly approved biometric reset is required.');
    }
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
          throw StateError('Source changed after biometric reset approval.');
        }
        final discoveredRows = await snapshot.store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 'fresh_finance_%'",
        ).get();
        final tables = discoveredRows
            .map((row) => row.read<String>('name')).toSet();
        if (tables.difference(_biometricKnownTables).isNotEmpty ||
            !tables.contains('fresh_finance_entries') ||
            !tables.contains('fresh_finance_categories') ||
            !tables.contains('fresh_finance_snapshot_state') ||
            !tables.contains('fresh_finance_receipts') ||
            !tables.contains('fresh_finance_sms_hashes')) {
          throw StateError('Unknown or incomplete encrypted finance schema.');
        }
        if ((await snapshot.store.customSelect(
          'PRAGMA foreign_key_check',
        ).get()).isNotEmpty) {
          throw StateError('Financial references are inconsistent.');
        }
        final entries = _ledger(current.values['entries'] as String?);
        await _verifyCurrentTypedLedger(entries);
        // Older SQL catalog versions can carry a second receipt index.
        // It contains hashes/names but NO file bytes. Only clear a legacy
        // index entry when its owner, position, name and content SHA match
        // an independently checked SQLCipher BLOB. Path-only external files
        // can never be called deleted by a SQL-only transaction.
        final legacyRows = await snapshot.store.customSelect(
          'SELECT entry_id,position,safe_filename,sha256_hex '
          'FROM fresh_finance_receipts',
        ).get();
        final legacyByPosition = <String, Map<String, String>>{};
        for (final row in legacyRows) {
          final owner = row.read<String>('entry_id');
          final position = row.read<int>('position');
          final key = jsonEncode([owner, position]);
          if (owner.isEmpty || position < 0 ||
              legacyByPosition.containsKey(key)) {
            throw StateError('Duplicate or invalid old receipt association.');
          }
          legacyByPosition[key] = <String, String>{
            'name': row.read<String>('safe_filename'),
            'sha': row.read<String>('sha256_hex'),
          };
        }
        var receiptCount = 0;
        final vault = WaffraEncryptedReceiptVault(
          store: snapshot.store, experimentalEnabled: true,
        );
        for (final entry in entries) {
          final slots = _receiptSlots(entry['receiptPath']);
          if (slots == 0) continue;
          final images = await vault.readAll(entry['id'] as String);
          if (images.length != slots) {
            throw StateError('Encrypted receipt count does not match ledger.');
          }
          for (var i = 0; i < slots; i++) {
            if (images[i].position != i) {
              throw StateError('Encrypted receipt order differs.');
            }
            final old = legacyByPosition.remove(
              jsonEncode([entry['id'] as String, i]),
            );
            if (old != null &&
                (old['name'] != images[i].safeName ||
                 old['sha'] != images[i].sha256Hex)) {
              throw StateError(
                'Old receipt metadata differs from encrypted attachment.',
              );
            }
          }
          receiptCount += slots;
        }
        if (legacyByPosition.isNotEmpty) {
          // No source path or external-file deletion is attempted here.
          // A dangling/file-backed index requires a separate verified
          // filesystem migration and must never be silently orphaned.
          throw StateError('Unverified file-backed receipt prevents reset.');
        }
        if (tables.contains('fresh_finance_receipt_blobs') &&
            await _count('fresh_finance_receipt_blobs') != receiptCount) {
          throw StateError('Unlinked encrypted receipt prevents reset.');
        }
        final hashes = current.values['waffra_sms_hashes_v1'] as List<String>? ??
            const <String>[];
        final sqlHashes = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes',
        ).get();
        if (sqlHashes.length != hashes.length ||
            sqlHashes.map((e) => e.read<String>('message_hash')).toSet()
                .difference(hashes.toSet()).isNotEmpty) {
          throw StateError('Financial SMS deduplication integrity mismatch.');
        }

        final targets = tables.difference(_biometricPreservedTables);
        final parents = <String, Set<String>>{};
        for (final table in targets) {
          // Table names come exclusively from the fixed known-table allowlist.
          final refs = await snapshot.store.customSelect(
            'PRAGMA foreign_key_list(' + table + ')',
          ).get();
          parents[table] = refs
              .map((row) => row.read<String>('table'))
              .where(targets.contains).toSet()..remove(table);
        }
        final remaining = <String>{...targets};
        while (remaining.isNotEmpty) {
          final children = remaining.where((candidate) =>
              !remaining.any((other) => other != candidate &&
                  (parents[other]?.contains(candidate) ?? false)))
              .toList()..sort();
          if (children.isEmpty) {
            throw StateError('Unresolvable financial foreign-key dependency.');
          }
          for (final table in children) {
            if (table == 'fresh_finance_categories') {
              // M452 refuses deletion of a parent while a subcategory exists.
              await snapshot.store.customStatement(
                "DELETE FROM fresh_finance_categories "
                "WHERE COALESCE(parent_id,'')<>''",
              );
            }
            await snapshot.store.customStatement('DELETE FROM ' + table);
            remaining.remove(table);
          }
        }
        final cleared = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: const <String, Object?>{
            'entries': '[]',
            // Even restored/migrated vaults must reopen with a known catalog.
            'waffra_categories_v24': '[]',
          },
        );
        for (final table in targets) {
          if (await _count(table) != 0) {
            throw StateError('Encrypted finance reset left records: ' + table);
          }
        }
        if ((await snapshot.store.customSelect(
          'PRAGMA foreign_key_check',
        ).get()).isNotEmpty ||
            _ledger(cleared.values['entries'] as String?).isNotEmpty ||
            cleared.values.length != 2 ||
            cleared.generation != current.generation + 1) {
          throw StateError('Biometric reset commit integrity mismatch.');
        }
        WaffraFinanceReadView.fromEncrypted(cleared).requireIntegrity();
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

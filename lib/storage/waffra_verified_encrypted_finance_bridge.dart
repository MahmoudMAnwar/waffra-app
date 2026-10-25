import 'waffra_encrypted_full_finance_reset.dart';
import 'waffra_encrypted_transaction_recycle.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'waffra_encrypted_cutover_journal.dart';
import 'waffra_encrypted_finance_ui_patch.dart';
import 'waffra_encrypted_module_projection_guard.dart';
import 'waffra_encrypted_module_recycle.dart';
import 'waffra_fresh_finance_modules_repository.dart';
import 'legacy_snapshot_preflight.dart';
import '../waffra_recurring_policy.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_encrypted_receipt_recycle.dart';
import 'waffra_receipt_screen_contract.dart';
import 'waffra_encrypted_receipt_read_gateway.dart';
import 'waffra_live_legacy_finance_guard.dart';
import 'waffra_unified_finance_writer.dart';

/// A single immutable read of the encrypted finance source. The revision can
/// also be observed by a separate Android widget engine and HomeScreen.
class WaffraEncryptedHomeWitness {
  const WaffraEncryptedHomeWitness({
    required this.snapshot,
    required this.finance,
  });

  final WaffraFinanceSnapshotState snapshot;
  final WaffraFinanceReadView finance;
  int get generation => snapshot.generation;
  String get digest => snapshot.digest;
  String? get ledgerRaw => finance.getString('entries');
  String get widgetRevision => snapshot.generation.toString();
}

/// Candidate runtime bridge for a future verified SQLCipher activation.
///
/// Runs the same source witness and file-lock check for HomeScreen and widget
/// finance mutations. Does NOT create an encrypted key or vault, set source
/// markers, migrate legacy data, or modify production app routing.
///
/// It must only be constructed for a previously activated vault with external
/// source and independently verified SQL witnesses. Flags here are supplied
/// by the future production activation coordinator, NOT a user preference.
class WaffraVerifiedEncryptedFinanceBridge {
  const WaffraVerifiedEncryptedFinanceBridge({
    required this.snapshot,
    required this.cutoverJournal,
    required this.writerDirectory,
    this.allWritersRoutedVerified = false,
    this.secureKeyVerified = false,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final WaffraEncryptedCutoverJournal cutoverJournal;
  final Directory writerDirectory;
  final bool allWritersRoutedVerified;
  final bool secureKeyVerified;
  final bool experimentalEnabled;

  Future<void> _requireActivatedUnderLock() async {
    if (!experimentalEnabled ||
        !allWritersRoutedVerified ||
        !secureKeyVerified) {
      throw StateError('Verified encrypted runtime is not enabled.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(WaffraLiveLegacyFinanceGuard.activeKey) != true ||
        prefs.containsKey(WaffraLiveLegacyFinanceGuard.pendingKey)) {
      throw StateError('Encrypted source witness is missing or pending.');
    }
    final recovery = await cutoverJournal.recover(
      externalMarkerPresent: true,
      encryptedKeyReadable: secureKeyVerified,
      allWritersRouted: allWritersRoutedVerified,
    );
    if (recovery != WaffraCutoverRecoveryStatus.encryptedReady) {
      throw StateError('SQLCipher activation witness needs reconciliation.');
    }
  }

  /// Encrypted-only, explicitly authenticated reset route. The independent
  /// source selector and the reset engine recheck the active SQLCipher
  /// checkpoint beneath the same native Home/Widget writer lock. A locally
  /// generated backup, UI button or in-memory certificate is never enough.
  Future<WaffraEncryptedFullResetResult> resetVerifiedFinance({
    required WaffraEncryptedHomeWitness baseline,
    required String encryptedBackup,
    required String backupPassword,
    required String confirmationPhrase,
    required bool userConfirmed,
    required bool biometricVerified,
    required bool externalBackupSaved,
  }) async {
    if (!experimentalEnabled || !allWritersRoutedVerified ||
        !secureKeyVerified) {
      throw StateError('Verified encrypted source is not available for reset.');
    }
    return WaffraEncryptedFullFinanceReset(
      snapshot: snapshot,
      writerDirectory: writerDirectory,
      verifySourceUnderLock: _requireActivatedUnderLock,
      experimentalEnabled: true,
    ).reset(
      baseline: baseline.snapshot,
      encryptedBackup: encryptedBackup,
      backupPassword: backupPassword,
      confirmationPhrase: confirmationPhrase,
      userConfirmed: userConfirmed,
      biometricVerified: biometricVerified,
      externalBackupSaved: externalBackupSaved,
    );
  }

  Future<WaffraEncryptedHomeWitness> loadForHomeAndWidget() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      return WaffraEncryptedHomeWitness(
        snapshot: current,
        finance: WaffraFinanceReadView.fromEncrypted(current),
      );
    });
  }

  /// Reads the typed, encrypted custom goal suggestions under the native
  /// Home/Widget lock and current dual source witnesses. A missing table or
  /// malformed position is a recovery incident, never an empty fallback.
  Future<List<String>> _customGoalRowsUnderLock() async {
    await snapshot.read();
    final exists = await snapshot.store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_custom_goals'",
    ).get();
    if (exists.length != 1) {
      throw StateError('Encrypted custom goals table is unavailable.');
    }
    final rows = await snapshot.store.customSelect(
      'SELECT position,suggestion FROM fresh_finance_custom_goals '
      'ORDER BY position ASC',
    ).get();
    if (rows.length > 1000) {
      throw StateError('Encrypted custom goal capacity is invalid.');
    }
    final normalized = <String>{};
    final result = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final name = entry.read<String>('suggestion');
      if (entry.read<int>('position') != i ||
          name.trim().isEmpty || name.length > 512 ||
          !normalized.add(name.trim().toLowerCase())) {
        throw StateError('Encrypted custom goal projection is inconsistent.');
      }
      result.add(name);
    }
    return List<String>.unmodifiable(result);
  }

  Future<List<String>> loadCustomGoalSuggestions() {
    if (!experimentalEnabled) {
      throw StateError('Encrypted custom goals are not active.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      return _customGoalRowsUnderLock();
    });
  }

  /// Inserts one suggestion after deduplicating with the latest encrypted
  /// table under the common native lock. SQL is the ONLY selected source.
  Future<bool> addCustomGoalSuggestion(String suggestion) {
    final name = suggestion.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Custom savings goal name must be 1–100 characters.');
    }
    if (!experimentalEnabled) {
      throw StateError('Encrypted custom goals are not active.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      return snapshot.store.transaction(() async {
        final previous = await _customGoalRowsUnderLock();
        if (previous.any((item) =>
            item.trim().toLowerCase() == name.toLowerCase())) {
          return false;
        }
        if (previous.length >= 1000) {
          throw StateError('Encrypted custom goal capacity exceeded.');
        }
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_custom_goals(position,suggestion) '
          'VALUES (?,?)',
          [previous.length, name],
        );
        final next = await _customGoalRowsUnderLock();
        if (next.length != previous.length + 1 ||
            next.last != name) {
          throw StateError('Encrypted custom goal durable write is inconsistent.');
        }
        return true;
      });
    });
  }

  /// Install catalog v2/v3 and the exact SQLCipher metadata marker in ONE
  /// transaction, under the shared Home/Widget writer lock. An unrelated
  /// Widget transaction survives; a concurrent catalog edit fails closed.
  Future<WaffraFinanceSnapshotState> installCategoryCatalog({
    required int version,
    required String? expectedCatalogRaw,
    required String nextCatalogRaw,
    required bool catalogChanged,
  }) async {
    if (version != 2 && version != 3) {
      throw ArgumentError('Unknown encrypted catalog version.');
    }
    if (!WaffraLegacyPreflight.inspect(
      <String, Object?>{'waffra_categories_v24': nextCatalogRaw},
    ).canStage) {
      throw StateError('Encrypted category catalog failed validation.');
    }
    if (!experimentalEnabled) {
      throw StateError('Encrypted catalog installer is disabled.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      return snapshot.store.transaction(() async {
        final previous = await snapshot.read();
        final observed = previous.values['waffra_categories_v24'];
        if (observed != expectedCatalogRaw) {
          throw StateError('Category catalog has changed; reload before install.');
        }
        if (!catalogChanged && observed != nextCatalogRaw) {
          throw StateError('Unconfirmed category catalog replacement refused.');
        }
        final marker = 'waffra_category_catalog_v${version}_installed';
        final rows = await snapshot.store.customSelect(
          'SELECT value_json FROM fresh_finance_settings '
          'WHERE setting_key=?',
          variables: [Variable.withString(marker)],
        ).get();
        if (rows.length > 1 ||
            (rows.isNotEmpty && rows.single.read<String>('value_json') != 'true')) {
          throw StateError('Encrypted catalog install marker is inconsistent.');
        }
        if (rows.isNotEmpty) {
          return previous;
        }
        var persisted = previous;
        if (catalogChanged) {
          await WaffraEncryptedModuleProjectionGuard.reconcile(
            store: snapshot.store,
            key: 'waffra_categories_v24',
            previousJson: observed as String?,
            updatedJson: nextCatalogRaw,
          );
          final changes = Map<String, Object?>.from(previous.values);
          changes['waffra_categories_v24'] = nextCatalogRaw;
          persisted = await snapshot.commit(
            expectedGeneration: previous.generation,
            fullFinanceSnapshot: changes,
          );
        }
        // SQLCipher marker is the LAST mutation in the same transaction.
        // Crash/rollback reverts BOTH the category projection and marker.
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_settings(setting_key,value_json) '
          'VALUES (?,?)',
          [marker, 'true'],
        );
        final markerRead = await snapshot.store.customSelect(
          'SELECT value_json FROM fresh_finance_settings WHERE setting_key=?',
          variables: [Variable.withString(marker)],
        ).get();
        if (markerRead.length != 1 ||
            markerRead.single.read<String>('value_json') != 'true') {
          throw StateError('Encrypted category catalog install was not durable.');
        }
        return persisted;
      });
    });
  }

  /// Delete a fully witnessed ledger without receipts, and clear its SMS
  /// dedupe hashes IN THE SAME SQL transaction. Receipt-bearing finance and
  /// orphan blobs deliberately fail closed until retention is certified.
  Future<WaffraFinanceSnapshotState> deleteAllUnattachedTransactions({
    required WaffraEncryptedHomeWitness baseline,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed) {
      throw StateError('Confirmed encrypted finance deletion is required.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        if (current.generation != baseline.generation ||
            current.digest != baseline.digest) {
          throw StateError('Finance changed; reload before deleting.');
        }
        final raw = current.values['entries'] as String? ?? '[]';
        final decoded = jsonDecode(raw);
        if (decoded is! List || decoded.any((row) =>
            row is! Map || row['id'] is! String ||
            (row['receiptPath'] != null && row['receiptPath'] != ''))) {
          throw StateError('Ledger contains unsafe or attached entries.');
        }
        final ids = decoded.map((row) => (row as Map)['id']).toSet();
        if (ids.length != decoded.length) {
          throw StateError('Ledger contains duplicate identities.');
        }
        final sql = await snapshot.store.customSelect(
          'SELECT entry_id,source_json,receipt_count FROM fresh_finance_entries',
        ).get();
        if (sql.length != decoded.length ||
            sql.any((row) => !ids.contains(row.read<String>('entry_id')) ||
                row.read<int>('receipt_count') != 0)) {
          throw StateError('Encrypted ledger projection differs from finance.');
        }
        final byId = <String, Object?>{
          for (final item in decoded) (item as Map)['id'] as String: item,
        };
        for (final row in sql) {
          if (jsonEncode(jsonDecode(row.read<String>('source_json'))) !=
              jsonEncode(byId[row.read<String>('entry_id')])) {
            throw StateError('Transaction SQL witness differs from ledger.');
          }
        }
        // NEVER silently discard attached, archived or orphan receipt bytes.
        for (final name in const <String>[
          'fresh_finance_receipt_blobs',
          'fresh_finance_receipt_recycle',
          'fresh_finance_receipts',
        ]) {
          final present = await snapshot.store.customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            variables: [Variable.withString(name)],
          ).get();
          if (present.isNotEmpty) {
            final count = await snapshot.store.customSelect(
              'SELECT count(*) AS n FROM $name',
            ).getSingle();
            if (count.read<int>('n') != 0) {
              throw StateError('Encrypted receipts require retention review.');
            }
          }
        }
        final hashes = current.values['waffra_sms_hashes_v1'];
        if (hashes != null && hashes is! List<String>) {
          throw StateError('Encrypted dedupe hashes are corrupted.');
        }
        final sqlHashes = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes',
        ).get();
        final actualHashes =
            sqlHashes.map((row) => row.read<String>('message_hash')).toSet();
        final expectedHashes = (hashes as List<String>? ?? const <String>[])
            .toSet();
        if (actualHashes.length != sqlHashes.length ||
            actualHashes.length != expectedHashes.length ||
            !actualHashes.containsAll(expectedHashes)) {
          throw StateError('SQLCipher hash projection differs from finance.');
        }
        await snapshot.store.customStatement(
          'DELETE FROM fresh_finance_entries',
        );
        await snapshot.store.customStatement(
          'DELETE FROM fresh_finance_sms_hashes',
        );
        final replacement = Map<String, Object?>.from(current.values)
          ..['entries'] = '[]'
          ..['waffra_sms_hashes_v1'] = <String>[];
        return snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: replacement,
        );
      });
    });
  }

  /// Combined recurring payment: the confirmed payment row, typed SQL ledger
  /// and removal of only that payment's postponement key commit atomically.
  /// A concurrent unrelated Widget transaction/hash is preserved, while
  /// changes to this schedule or postponement fail closed. Never use this for
  /// transactions carrying receipts, for which the BLOB writer is mandatory.
  Future<WaffraFinanceSnapshotState> commitRecurringPayment({
    required WaffraEncryptedHomeWitness baseline,
    required Map<String, Object?> record,
    required String proposedPostponedJson,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed) {
      throw StateError('An explicitly confirmed encrypted payment is required.');
    }
    // Freeze the caller-owned map BEFORE any source probe or awaited lock.
    final frozen = Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(record)) as Map<String, dynamic>,
      ),
    );
    if (!WaffraLegacyPreflight.inspect(
      <String, Object?>{'entries': jsonEncode([frozen])},
    ).canStage || frozen['receiptPath'] != null && frozen['receiptPath'] != '') {
      throw StateError('Unverified recurring payment or receipt payload.');
    }
    final id = frozen['id'];
    final when = DateTime.tryParse(frozen['date'] is String
        ? frozen['date'] as String : '');
    final amount = frozen['amount'];
    if (id is! String || id.isEmpty || id.length > 256 ||
        when == null || amount is! num ||
        !WaffraLegacyPreflight.canRepresentHalalas(amount) ||
        amount < 0 || frozen['income'] is! bool ||
        frozen['title'] is! String || frozen['category'] is! String) {
      throw StateError('Recurring payment record is invalid.');
    }
    Map<String, Object?> decodePostponed(String raw) {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data.entries.any((e) => e.value is! String)) {
        throw StateError('Postponed recurring map is malformed.');
      }
      return Map<String, Object?>.from(data);
    }
    final proposed = decodePostponed(proposedPostponedJson);
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        if (current.values['waffra_recurring_v24'] !=
                baseline.snapshot.values['waffra_recurring_v24'] ||
            current.values['waffra_recurring_postponed_v1'] !=
                baseline.snapshot.values['waffra_recurring_postponed_v1']) {
          throw StateError('Recurring schedule or postponement changed.');
        }
        final previousPostponed = decodePostponed(
          (current.values['waffra_recurring_postponed_v1'] as String?) ?? '{}',
        );
        final schedulesRaw = jsonDecode(
          (current.values['waffra_recurring_v24'] as String?) ?? '[]',
        );
        if (schedulesRaw is! List || schedulesRaw.any((s) => s is! Map)) {
          throw StateError('Encrypted recurring schedule is corrupted.');
        }
        final schedules = schedulesRaw.map((s) =>
            Map<String, Object?>.from(s as Map)).toList(growable: false);
        final scheduleIds = schedules.map((s) => s['id']).toSet();
        if (scheduleIds.length != schedules.length) {
          throw StateError('Encrypted recurring identities are ambiguous.');
        }
        final relational = await snapshot.store.customSelect(
          'SELECT recurring_id,source_json,amount_minor,is_income,due_day '
          'FROM fresh_finance_recurring',
        ).get();
        if (relational.length != schedules.length) {
          throw StateError('Recurring SQL projection count differs.');
        }
        final indexed = <String, Map<String, Object?>>{
          for (final s in schedules) s['id'] as String: s,
        };
        for (final row in relational) {
          final key = row.read<String>('recurring_id');
          final saved = indexed[key];
          if (saved == null ||
              jsonEncode(saved) !=
                  jsonEncode(jsonDecode(row.read<String>('source_json'))) ||
              saved['amount'] is! num ||
              ((saved['amount'] as num) * 100).round() !=
                  row.read<int>('amount_minor') ||
              saved['day'] != row.read<int>('due_day') ||
              (saved['income'] == true ? 1 : 0) !=
                  row.read<int>('is_income')) {
            throw StateError('Recurring typed SQL witness differs.');
          }
        }
        final matching = schedules.where((s) {
          final sid = s['id'];
          final day = s['day'];
          if (sid is! String || day is! int || day < 1 || day > 31) {
            return false;
          }
          final due = WaffraRecurringPolicy.dueDate(
            when.year, when.month, day,
          );
          return WaffraRecurringPolicy.entryId(sid, due) == id;
        }).toList();
        if (matching.length != 1) {
          throw StateError('Payment is not linked to one recurring schedule.');
        }
        final schedule = matching.single;
        final startAt = DateTime.tryParse(
          schedule['startAt'] is String ? schedule['startAt'] as String : '',
        );
        final due = WaffraRecurringPolicy.dueDate(
          when.year, when.month, schedule['day'] as int,
        );
        if (schedule['active'] == false || startAt == null ||
            due.isBefore(DateTime(startAt.year,startAt.month,startAt.day)) ||
            frozen['title'] != schedule['title'] ||
            frozen['category'] != schedule['category'] ||
            frozen['income'] != schedule['income'] ||
            frozen['amount'] != schedule['amount']) {
          throw StateError('Recurring posted payment differs from its schedule.');
        }
        final expectedPostponed = Map<String, Object?>.from(previousPostponed)
          ..remove(id);
        if (jsonEncode(expectedPostponed) != jsonEncode(proposed)) {
          throw StateError('Recurring payment may only clear its own postponement.');
        }
        final snapshotRows = jsonDecode(
          (current.values['entries'] as String?) ?? '[]',
        );
        if (snapshotRows is! List || snapshotRows.any((x) => x is! Map)) {
          throw StateError('Current recurring payment ledger is malformed.');
        }
        final entries = snapshotRows.map((x) =>
            Map<String, Object?>.from(x as Map)).toList();
        final ids = entries.map((x) => x['id']).toSet();
        if (ids.length != entries.length || ids.contains(id)) {
          throw StateError('Recurring payment is already posted.');
        }
        final typed = await snapshot.store.customSelect(
          'SELECT entry_id,source_json FROM fresh_finance_entries',
        ).get();
        final byId = <String, Map<String, Object?>>{
          for (final item in entries) item['id'] as String: item,
        };
        if (typed.length != entries.length || typed.any((row) =>
            !byId.containsKey(row.read<String>('entry_id')) ||
            jsonEncode(byId[row.read<String>('entry_id')]) !=
                jsonEncode(jsonDecode(row.read<String>('source_json'))))) {
          throw StateError('Recurring payment SQL ledger is out of sync.');
        }
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
          [
            id, frozen['title'], frozen['category'], (amount * 100).round(),
            frozen['income'] == true ? 1 : 0,
            frozen['date'], jsonEncode(frozen),
          ],
        );
        final next = Map<String, Object?>.from(current.values)
          ..['entries'] = jsonEncode([frozen, ...entries])
          ..['waffra_recurring_postponed_v1'] = proposedPostponedJson;
        return snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
      });
    });
  }

  /// Never expose the module recycle against an unverified encrypted source.
  /// Each call independently rechecks source/key/cutover under the shared
  /// Home/Widget native writer lock inside the standalone recycle writer.
  WaffraEncryptedModuleRecycle get _verifiedModuleRecycle =>
      WaffraEncryptedModuleRecycle(
        snapshot: snapshot,
        writerDirectory: writerDirectory,
        verifySourceUnderLock: _requireActivatedUnderLock,
        experimentalEnabled: experimentalEnabled,
      );

  Future<WaffraEncryptedModuleRecycleResult> recycleVerifiedModule({
    required WaffraEncryptedHomeWitness baseline,
    required WaffraFinanceModule module,
    required String entityId,
    required DateTime now,
    required bool userConfirmed,
  }) {
    if (!experimentalEnabled) {
      throw StateError('Encrypted module recycle source is not active.');
    }
    return _verifiedModuleRecycle.softDelete(
      module: module,
      baseline: baseline.snapshot,
      entityId: entityId,
      now: now,
      userConfirmed: userConfirmed,
    );
  }

  Future<WaffraEncryptedModuleRecycleResult> restoreVerifiedModule({
    required WaffraEncryptedHomeWitness baseline,
    required WaffraFinanceModule module,
    required String entityId,
    required DateTime now,
  }) {
    if (!experimentalEnabled) {
      throw StateError('Encrypted module restore source is not active.');
    }
    return _verifiedModuleRecycle.restore(
      module: module,
      baseline: baseline.snapshot,
      entityId: entityId,
      now: now,
    );
  }

  Future<Map<String, int>> listVerifiedDeletedModules(
    WaffraFinanceModule module,
  ) {
    if (!experimentalEnabled) {
      throw StateError('Encrypted module trash source is not active.');
    }
    return _verifiedModuleRecycle.pending(module);
  }

  /// Applies only user-edited finance keys. If a widget saved an unrelated
  /// field meanwhile, that value survives; a same-key edit fails closed.
  Future<WaffraFinanceSnapshotState> saveHomeChanges({
    required WaffraEncryptedHomeWitness baseline,
    required Map<String, Object?> replacements,
    required Set<String> changedKeys,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraEncryptedFinanceUiPatch(
      snapshot: snapshot,
      writerDirectory: writerDirectory,
      experimentalEnabled: true,
      verifySourceUnderLock: _requireActivatedUnderLock,
    ).saveScreenChanges(
      screenBaseline: baseline.snapshot.values,
      replacementValues: replacements,
      changedKeys: changedKeys,
    );
  }

  /// Receives explicitly confirmed SMS/manual transaction JSON from either
  /// engine. Dedupe and ledger update commit together under ONE source lock.
  Future<WaffraUnifiedWriteResult> appendConfirmedTransactions({
    required List<Map<String, Object?>> records,
    required List<String?> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
    List<Map<String,Object?>> proposedCategories = const [],
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted source bridge is disabled by default.');
    }
    return WaffraUnifiedFinanceWriter(
      writerDirectory: writerDirectory,
      snapshot: snapshot,
      experimentalEnabled: true,
      verifySourceUnderLock: _requireActivatedUnderLock,
    ).appendTransactions(
      records: records,
      messageHashes: messageHashes,
      userConfirmed: userConfirmed,
      allowDuplicateHashes: allowDuplicateHashes,
      proposedCategories: proposedCategories,
    );
  }
  /// Save a confirmed transaction and its attached images as ONE encrypted
  /// SQLCipher commit. Uses the same source witness as dashboard and widget.
  /// No plaintext disk receipt path or separate partial finance update.
  Future<WaffraEncryptedReceiptTransactionResult>
      appendConfirmedWithReceiptBytes({
    required Map<String, Object?> record,
    required List<Uint8List> images,
    required bool userConfirmed,
    String? messageHash,
  }) {
    return WaffraAtomicEncryptedReceiptTransactionWriter(
      snapshot: snapshot,
      receiptVault: WaffraEncryptedReceiptVault(
        store: snapshot.store,
        experimentalEnabled: true,
      ),
      writerDirectory: writerDirectory,
      verifySourceUnderLock: _requireActivatedUnderLock,
      experimentalEnabled: experimentalEnabled,
    ).save(
      record: record,
      receiptImages: images,
      userConfirmed: userConfirmed,
      smsHash: messageHash,
    );
  }

  /// Replace one existing image after verifying source and the expected
  /// previous image digest under the common Home/Widget native lock.
  /// Never delete, renumber, or modify transaction history in this path.
  Future<void> replaceVerifiedReceiptImage({
    required String entryId,
    required int position,
    required Uint8List image,
    required String expectedSha256,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt replacement is disabled.');
    }
    final captured = Uint8List.fromList(image);
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      final raw = current.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted finance ledger is unavailable.');
      }
      final rows = jsonDecode(raw);
      if (rows is! List) {
        throw StateError('Encrypted finance ledger is malformed.');
      }
      final matching = rows.where((row) =>
          row is Map && row['id'] == entryId).toList();
      if (matching.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final refs = (matching.single as Map)['receiptPath'];
      if (refs is! String || refs.isEmpty) {
        throw StateError('Encrypted receipt references are missing.');
      }
      final vault = WaffraEncryptedReceiptVault(
        store: snapshot.store, experimentalEnabled: true,
      );
      final prior = await vault.readAll(entryId);
      if (position < 0 || position >= prior.length) {
        throw StateError('Encrypted receipt position is invalid.');
      }
      // The existing verified read gateway checks that references and blobs
      // belong to this same transaction before any destructive mutation.
      await WaffraEncryptedReceiptReadGateway(
        receiptVault: vault,
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(entryId: entryId, encodedReferences: refs);
      await vault.replaceExistingImage(
        entryId: entryId,
        position: position,
        image: captured,
        expectedSha256: expectedSha256,
      );
    });
  }

  WaffraEncryptedTransactionRecycle get _transactionRecycle =>
      WaffraEncryptedTransactionRecycle(
        snapshot: snapshot,
        writerDirectory: writerDirectory,
        verifySourceUnderLock: _requireActivatedUnderLock,
        experimentalEnabled: experimentalEnabled,
      );

  /// A verified SQLCipher-only transaction deletion. The source witness,
  /// ledger+typed SQL parity and all image SHA-256 witnesses are checked under
  /// the shared Home/Widget native lock before a single durable commit.
  Future<WaffraTransactionRecycleResult> recycleVerifiedTransaction({
    required WaffraEncryptedHomeWitness baseline,
    required String entryId,
    required List<String> expectedImageHashes,
    required DateTime now,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed) {
      throw StateError('Encrypted transaction deletion requires confirmation.');
    }
    return _transactionRecycle.delete(
      baseline: baseline.snapshot,
      entryId: entryId,
      expectedImageHashes: List<String>.unmodifiable(expectedImageHashes),
      now: now,
      userConfirmed: userConfirmed,
    );
  }

  /// Restore exactly one previously deleted transaction with all its
  /// encrypted invoice bytes. Current finance generation must be unchanged.
  Future<WaffraTransactionRecycleResult> restoreVerifiedTransaction({
    required WaffraEncryptedHomeWitness baseline,
    required String entryId,
    required DateTime now,
  }) {
    if (!experimentalEnabled) {
      throw StateError('Encrypted transaction recovery is disabled.');
    }
    return _transactionRecycle.restore(
      baseline: baseline.snapshot, entryId: entryId, now: now,
    );
  }

  Future<Map<String, int>> listEncryptedDeletedTransactions() {
    if (!experimentalEnabled) {
      throw StateError('Encrypted transaction trash is disabled.');
    }
    return _transactionRecycle.pendingRecoveries();
  }

  WaffraEncryptedReceiptRecycle get _receiptRecycle =>
      WaffraEncryptedReceiptRecycle(
        snapshot: snapshot,
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store,
          experimentalEnabled: true,
        ),
        writerDirectory: writerDirectory,
        verifySourceUnderLock: _requireActivatedUnderLock,
        experimentalEnabled: experimentalEnabled,
      );

  /// Screen reads always use encrypted in-memory BLOBs, a single finance
  /// generation and the 30-day recycle witness. No plain file fallback.
  /// A concurrent writer forces the UI to reload instead of showing a
  /// mismatched receipt count or archive status.
  Future<WaffraReceiptScreenState> loadVerifiedReceiptScreen(
    String entryId,
  ) async {
    if (!experimentalEnabled || entryId.trim().isEmpty ||
        entryId.length > 128) {
      throw StateError('Verified encrypted receipt screen is unavailable.');
    }

    // M121: the legacy four-lock sequence could combine an old image set
    // with a newer recycle status or in-place M116 replacement. A receipt
    // replacement does not increment the finance generation. Capture the
    // ledger, normalized SQL owner, BLOB bytes and recycle status beneath
    // ONE Home/Widget native lock, with no public file or legacy fallback.
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final finance = await snapshot.read();
      final raw = finance.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted financial ledger is missing.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw StateError('Encrypted transaction list is malformed.');
      }
      final matching = decoded.where(
        (item) => (item as Map)['id'] == entryId,
      ).toList();
      if (matching.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final owner = Map<String, dynamic>.from(matching.single as Map);
      final refs = owner['receiptPath'];
      if (refs != null && refs is! String) {
        throw StateError('Encrypted receipt reference has an invalid type.');
      }

      // Refuse a split-brain ledger even if the JSON snapshot itself is valid.
      final sqlOwner = await snapshot.store.customSelect(
        'SELECT source_json,receipt_count FROM fresh_finance_entries '
        'WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).get();
      if (sqlOwner.length != 1 ||
          jsonEncode(jsonDecode(sqlOwner.single.read<String>('source_json'))) !=
              jsonEncode(owner)) {
        throw StateError('Encrypted receipt SQL owner differs from ledger.');
      }

      final imageBytes = await WaffraEncryptedReceiptReadGateway(
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store,
          experimentalEnabled: true,
        ),
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(entryId: entryId, encodedReferences: refs as String?);
      if (sqlOwner.single.read<int>('receipt_count') != imageBytes.length) {
        throw StateError('Encrypted receipt SQL count differs from images.');
      }

      int? recoverUntilMs;
      final table = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_receipt_recycle'",
      ).get();
      if (table.isNotEmpty) {
        final archived = await snapshot.store.customSelect(
          'SELECT receipt_count,deleted_at_ms,expires_at_ms '
          'FROM fresh_finance_receipt_recycle WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (archived.length > 1) {
          throw StateError('Duplicated encrypted receipt archive.');
        }
        final orphanCheck = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM fresh_finance_receipt_recycle_blobs '
          'WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).getSingle();
        final archivedCount = orphanCheck.read<int>('n');
        if (archived.isEmpty) {
          if (archivedCount != 0) {
            throw StateError('Orphaned encrypted receipt archive BLOBs.');
          }
        } else {
          final row = archived.single;
          final deletedAt = row.read<int>('deleted_at_ms');
          final expiry = row.read<int>('expires_at_ms');
          if (refs != null || imageBytes.isNotEmpty ||
              row.read<int>('receipt_count') != archivedCount ||
              archivedCount < 1 ||
              archivedCount > WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
              deletedAt < 0 ||
              expiry - deletedAt !=
                  WaffraEncryptedReceiptRecycle.retention.inMilliseconds) {
            throw StateError('Encrypted receipt archive witness mismatch.');
          }
          recoverUntilMs = expiry;
        }
      }

      // Check the durable source again before publishing UI data. This is
      // still under the same writer lock, so a cooperating widget cannot
      // interleave a finance write or an image replacement.
      await _requireActivatedUnderLock();
      final unchanged = await snapshot.read();
      if (unchanged.generation != finance.generation ||
          unchanged.digest != finance.digest) {
        throw StateError('Encrypted finance source changed during receipt read.');
      }
      return WaffraReceiptScreenState(
        entryId: entryId,
        generation: finance.generation,
        images: imageBytes,
        recoverUntilMs: recoverUntilMs,
      );
    });
  }

  Future<WaffraReceiptRecycleResult> moveReceiptBatchToRecycle({
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  }) {
    if (!experimentalEnabled || !baseline.hasActiveImages ||
        baseline.isInRecycleBin) {
      throw StateError('No verified active receipt batch may be removed.');
    }
    return _receiptRecycle.moveToRecycle(
      entryId: baseline.entryId,
      expectedGeneration: baseline.generation,
      expectedImageHashes: List<String>.unmodifiable(baseline.imageSha256),
      now: now,
      userConfirmed: userConfirmed,
    );
  }

  Future<WaffraReceiptRecycleResult> restoreReceiptBatchFromRecycle({
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  }) {
    if (!experimentalEnabled || !baseline.isInRecycleBin ||
        baseline.hasActiveImages) {
      throw StateError('No archived receipt batch is eligible for restore.');
    }
    return _receiptRecycle.restore(
      entryId: baseline.entryId,
      expectedGeneration: baseline.generation,
      now: now,
    );
  }

  /// Merge confirmed SHA-256 SMS fingerprints under one native app/widget lock.
  /// No raw bank SMS is stored or sent anywhere.
  Future<WaffraFinanceSnapshotState> mergeConfirmedSmsHashes(
    List<String> additions,
  ) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted SMS deduplication runtime is disabled.');
    }
    const digits = '0123456789abcdef';
    bool validHash(String hash) =>
        hash.length == 64 &&
        hash.split('').every((character) => digits.contains(character));
    if (additions.length > 1000 || additions.any((hash) => !validHash(hash))) {
      throw ArgumentError('Only SHA-256 SMS fingerprints are allowed.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      // Never update the canonical snapshot without its typed SQL hash
      // projection: a crash could otherwise leave two authoritative views.
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        final legacyTyped = current.values['waffra_sms_hashes_v1'];
        if (legacyTyped != null && legacyTyped is! List<String>) {
          throw StateError('Canonical SMS fingerprints have invalid type.');
        }
        final prior = legacyTyped as List<String>? ?? const <String>[];
        final existing = prior.toSet();
        if (prior.length != existing.length || existing.any((h) => !validHash(h))) {
          throw StateError('Canonical SMS fingerprints are inconsistent.');
        }
        final typedRows = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes',
        ).get();
        final typed = typedRows
            .map((row) => row.read<String>('message_hash')).toSet();
        if (typedRows.length != typed.length ||
            typed.length != existing.length ||
            !typed.containsAll(existing)) {
          throw StateError('SQLCipher SMS hash projection is inconsistent.');
        }
        final nextHashes = <String>{...existing, ...additions};
        if (nextHashes.length == existing.length) return current;
        if (nextHashes.length > 100000) {
          throw StateError('Encrypted SMS fingerprint capacity exceeded.');
        }
        for (final hash in nextHashes.difference(existing)) {
          await snapshot.store.customStatement(
            'INSERT OR IGNORE INTO fresh_finance_sms_hashes '
            '(message_hash) VALUES (?)',
            [hash],
          );
        }
        final next = Map<String, Object?>.from(current.values)
          ..['waffra_sms_hashes_v1'] = (nextHashes.toList()..sort());
        return snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
      });
    });
  }

  /// Read only existing and owner-verified encrypted attachment BLOBs.
  Future<List<Uint8List>> loadReceiptImages({required String entryId}) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt runtime is disabled by default.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await _requireActivatedUnderLock();
      final current = await snapshot.read();
      final raw = current.values['entries'];
      if (raw is! String) {
        throw StateError('Encrypted finance ledger is unavailable.');
      }
      final rows = jsonDecode(raw);
      if (rows is! List) {
        throw StateError('Encrypted finance ledger is malformed.');
      }
      final exact = rows.where((row) =>
          row is Map && row['id'] == entryId).toList();
      if (exact.length != 1) {
        throw StateError('Encrypted receipt owner is missing or duplicated.');
      }
      final references = (exact.single as Map)['receiptPath'];
      if (references != null && references is! String) {
        throw StateError('Encrypted receipt references are malformed.');
      }
      return WaffraEncryptedReceiptReadGateway(
        receiptVault: WaffraEncryptedReceiptVault(
          store: snapshot.store, experimentalEnabled: true,
        ),
        experimentalEnabled: true,
        verifyEncryptedSource: _requireActivatedUnderLock,
      ).read(
        entryId: entryId,
        encodedReferences: references as String?,
      );
    });
  }

}

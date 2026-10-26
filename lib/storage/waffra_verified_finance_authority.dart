import 'dart:convert';
import 'dart:typed_data';

import 'waffra_encrypted_sms_notes_vault.dart';
import 'waffra_encrypted_full_finance_reset.dart';
import 'waffra_encrypted_finance_session.dart';
import 'waffra_receipt_screen_contract.dart';
import 'waffra_encrypted_receipt_recycle.dart';
import 'waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_fresh_finance_modules_repository.dart';
import 'waffra_home_finance_persistence.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_production_finance_source_guard.dart';
import 'waffra_runtime_finance_route_contract.dart';
import 'waffra_verified_encrypted_finance_bridge.dart';

/// Source-specific immutable witness for app and standalone Android widget.
class WaffraFinanceAuthorityRead {
  const WaffraFinanceAuthorityRead({
    required this.finance,
    required this.source,
    required this.widgetRevision,
    required this.ledgerRaw,
    this.encryptedWitness,
  });
  final WaffraFinanceReadView finance;
  final WaffraRuntimeFinanceBackend source;
  final String? widgetRevision;
  final String? ledgerRaw;
  final WaffraEncryptedHomeWitness? encryptedWitness;
}

class WaffraFinanceAuthoritySmsCommit {
  const WaffraFinanceAuthoritySmsCommit({
    required this.saved,
    required this.income,
    required this.expenses,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.skippedDuplicates,
    required this.current,
    this.originalSmsNotesOmittedOnLegacy = false,
  });
  /// Only structured transaction metadata is saved on unencrypted legacy.
  final bool originalSmsNotesOmittedOnLegacy;
  final int saved, income, expenses, skippedDuplicates;
  final int incomeMinor, expenseMinor;
  final WaffraFinanceAuthorityRead current;
}

/// One fail-closed backend selector for BOTH Home and Widget.
/// The default constructor cannot activate SQLCipher: every live route,
/// on-device key, SQL/external witness, rollback and backup must have
/// independent verified release evidence before session injection.
class WaffraVerifiedFinanceAuthority {
  const WaffraVerifiedFinanceAuthority({
    this.legacy = const WaffraHomeFinancePersistence(),
    this.sourceGuard = const WaffraProductionFinanceSourceGuard(),
    this.encryptedSession,
    this.audit = const WaffraFinanceRouteAudit(),
    this.encryptedSqlWitnessActive = false,
    this.externalSourceWitnessActive = false,
    this.verifiedKeyRecoveryInDevice = false,
    this.protectedSmsNotes,
  });

  final WaffraHomeFinancePersistence legacy;
  final WaffraProductionFinanceSourceGuard sourceGuard;
  final WaffraEncryptedFinanceSession? encryptedSession;
  final WaffraFinanceRouteAudit audit;
  final bool encryptedSqlWitnessActive;
  final bool externalSourceWitnessActive;
  final bool verifiedKeyRecoveryInDevice;
  /// Production guarded-legacy paths stage originals in a separate SQLCipher
  /// vault BEFORE the legacy writer sees redacted financial metadata.
  final WaffraEncryptedSmsNotesVault? protectedSmsNotes;

  /// Only an unambiguous, already committed SMS ledger ID may open any
  /// decrypted original or user annotation. A staged orphan is never enough.
  Future<bool> _hasAuthoritativeSmsEntry(String entryId) async {
    if (entryId.trim().isEmpty || entryId.length > 128) return false;
    final current = await load(route: WaffraFinanceRoute.dashboardRead);
    final ledger = current.ledgerRaw;
    if (ledger == null) return false;
    final rows = jsonDecode(ledger);
    if (rows is! List) {
      throw StateError('Invalid authoritative SMS ledger.');
    }
    final matches = rows.where((row) =>
        row is Map && row['id'] == entryId).toList();
    return matches.length == 1 &&
        (matches.single as Map)['sourceType'] == 'sms';
  }

  /// Only resolve a protected original for an existing authoritative SMS ID.
  /// A staged-but-not-committed ID must never expose any raw bank note.
  Future<String?> readProtectedOriginalSms(String entryId) async {
    if (protectedSmsNotes == null ||
        !await _hasAuthoritativeSmsEntry(entryId)) return null;
    return protectedSmsNotes!.readVerifiedEntry(entryId);
  }

  /// A user annotation is distinct from the byte-exact, immutable original
  /// message. Guarded legacy keeps both inside SQLCipher, never preferences.
  Future<String?> readProtectedSmsUserNote(String entryId) async {
    if (protectedSmsNotes == null ||
        !await _hasAuthoritativeSmsEntry(entryId)) return null;
    return protectedSmsNotes!.readVerifiedUserNote(entryId);
  }

  Future<void> updateProtectedSmsUserNote({
    required String entryId,
    required String expectedNote,
    required String nextNote,
  }) async {
    if (protectedSmsNotes == null ||
        await _requireRoute(WaffraFinanceRoute.transactionEdit) !=
            WaffraRuntimeFinanceBackend.guardedLegacy ||
        !await _hasAuthoritativeSmsEntry(entryId)) {
      throw StateError('Verified legacy SMS annotation source unavailable.');
    }
    await protectedSmsNotes!.updateVerifiedUserNote(
      entryId: entryId,
      expectedNote: expectedNote,
      nextNote: nextNote,
    );
  }


  Future<WaffraRuntimeFinanceBackend> _requireRoute(
      WaffraFinanceRoute route) async {
    final report = await sourceGuard.inspect();
    final backend = WaffraRuntimeFinanceRouteContract(
      source: report,
      audit: audit,
      encryptedSqlWitnessActive: encryptedSqlWitnessActive,
      externalSourceWitnessActive: externalSourceWitnessActive,
      verifiedKeyRecoveryInDevice: verifiedKeyRecoveryInDevice,
    ).requireRoute(route);
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        encryptedSession == null) {
      throw StateError('Verified encrypted finance runtime is missing.');
    }
    return backend;
  }

  /// Complete the already-existing encrypted SMS-hash route; the current
  /// guarded legacy branch merges under the SAME widget/dashboard lock.
  /// Never accepts raw SMS, never selects a second empty finance source.
  Future<WaffraFinanceAuthorityRead> mergeSmsHashes(
      Iterable<String> newHashes) async {
    final frozen = List<String>.unmodifiable(newHashes);
    const hex = '0123456789abcdef';
    if (frozen.length > 1000 || frozen.any((hash) =>
        hash.length != 64 || hash.split('').any((c) => !hex.contains(c)))) {
      throw ArgumentError('Only SHA-256 transaction fingerprints are accepted.');
    }
    final backend = await _requireRoute(
      WaffraFinanceRoute.merchantRulesAndSmsHashes,
    );
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      await legacy.mergeSmsHashes(frozen);
    } else {
      // SQLCipher bridge atomically merges under its verified native lock;
      // its independent durable source witness must also be active.
      await encryptedSession!.addSmsHashes(frozen);
    }
    return load(route: WaffraFinanceRoute.merchantRulesAndSmsHashes);
  }

  /// Save finance-linked notification settings without a direct preferences
  /// escape hatch. SQL backend deliberately blocks this scalar until a
  /// separately tested, atomic encrypted scalar projection is approved.
  Future<WaffraFinanceAuthorityRead> setRecurringReminderPreference(
      bool enabled) async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    );
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      await legacy.setRecurringReminderPreference(enabled);
    } else {
      // A real encrypted write only after the independently audited route,
      // durable SQL/external witnesses and OS-backed key checks agree.
      // This never falls back to old preferences if the source is uncertain.
      final baseline = await encryptedSession!.loadForDashboardOrWidget();
      await encryptedSession!.saveRecurringReminderPreference(
        baseline: baseline,
        enabled: enabled,
      );
    }
    // Never publish an optimistic toggle before a durable source read.
    return load(route: WaffraFinanceRoute.recurringCreateEditDeleteRestore);
  }

  /// Custom suggestions are outside the canonical encrypted finance snapshot
  /// today. Never read them from old preferences after source activation.
  Future<List<String>> loadCustomGoalSuggestions() async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      return legacy.loadCustomGoalSuggestions();
    }
    return encryptedSession!.loadCustomGoalSuggestions();
  }

  Future<bool> addCustomGoalSuggestion(String name) async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      return legacy.addCustomGoalSuggestion(name);
    }
    return encryptedSession!.addCustomGoalSuggestion(name);
  }

  /// A guarded startup catalog version install with current-value CAS. The
  /// existing source and native writer lock are revalidated before mutation.
  Future<WaffraFinanceAuthorityRead> installCategoryCatalog({
    required int version,
    required String? expectedCatalogRaw,
    required String nextCatalogRaw,
    required bool catalogChanged,
  }) async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.categoryCatalogInstall,
    );
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      await legacy.installCategoryCatalog(
        version: version,
        expectedCatalogRaw: expectedCatalogRaw,
        nextCatalogRaw: nextCatalogRaw,
        catalogChanged: catalogChanged,
      );
    } else {
      // Do not touch legacy prefs after a verified encrypted selection.
      // The bridge rechecks active source witnesses inside its native lock.
      await encryptedSession!.installCategoryCatalog(
        version: version,
        expectedCatalogRaw: expectedCatalogRaw,
        nextCatalogRaw: nextCatalogRaw,
        catalogChanged: catalogChanged,
      );
    }
    return load(route: WaffraFinanceRoute.categoryCatalogInstall);
  }

  /// Encrypted-only transaction delete + 30-day undo. The live legacy UI
  /// remains on its existing guarded journal until real source cutover.
  Future<WaffraFinanceAuthorityRead> deleteVerifiedTransactionToRecycle({
    required WaffraFinanceAuthorityRead baseline,
    required String entryId,
    required List<String> expectedImageHashes,
    required bool userConfirmed,
    required DateTime now,
  }) async {
    if (!userConfirmed || entryId.trim().isEmpty ||
        entryId.length > 128) {
      throw StateError('Confirmed transaction deletion is required.');
    }
    final hashes = List<String>.unmodifiable(expectedImageHashes);
    final backend = await _requireRoute(
      WaffraFinanceRoute.transactionDeleteAndUndo,
    );
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.source != backend || baseline.encryptedWitness == null) {
      throw StateError('Encrypted transaction deletion has no source witness.');
    }
    await encryptedSession!.recycleVerifiedTransaction(
      baseline: baseline.encryptedWitness!,
      entryId: entryId,
      expectedImageHashes: hashes,
      now: now,
      userConfirmed: userConfirmed,
    );
    // A confirmed UI mutation is not successful until source reopens.
    return load(route: WaffraFinanceRoute.transactionDeleteAndUndo);
  }

  Future<WaffraFinanceAuthorityRead> restoreVerifiedDeletedTransaction({
    required WaffraFinanceAuthorityRead baseline,
    required String entryId,
    required DateTime now,
  }) async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.transactionDeleteAndUndo,
    );
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.source != backend || baseline.encryptedWitness == null ||
        entryId.trim().isEmpty || entryId.length > 128) {
      throw StateError('Encrypted transaction undo has no valid source witness.');
    }
    await encryptedSession!.restoreVerifiedTransaction(
      baseline: baseline.encryptedWitness!, entryId: entryId, now: now,
    );
    return load(route: WaffraFinanceRoute.transactionDeleteAndUndo);
  }

  Future<Map<String, int>> listVerifiedDeletedTransactions() async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.transactionDeleteAndUndo,
    );
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Encrypted recycle list cannot expose legacy storage.');
    }
    return encryptedSession!.listEncryptedDeletedTransactions();
  }

  static WaffraFinanceRoute _verifiedModuleRoute(
    WaffraFinanceModule module,
  ) => switch (module) {
    WaffraFinanceModule.categories =>
      WaffraFinanceRoute.categoryCreateEditDeleteRestore,
    WaffraFinanceModule.goals =>
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
    WaffraFinanceModule.recurring =>
      WaffraFinanceRoute.recurringCreateEditDeleteRestore,
  };

  /// Delete exactly one verified finance entity and ALL of its matching
  /// active typed projection in one encrypted commit. The guarded legacy
  /// source is deliberately unsupported; no fallback may silently lose its
  /// linked financial history or corrupt the pending encrypted trash.
  Future<WaffraFinanceAuthorityRead> deleteVerifiedModuleToRecycle({
    required WaffraFinanceAuthorityRead baseline,
    required WaffraFinanceModule module,
    required String entityId,
    required DateTime now,
    required bool userConfirmed,
  }) async {
    final route = _verifiedModuleRoute(module);
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.encryptedWitness == null || !userConfirmed) {
      throw StateError('Verified encrypted module deletion is not authorized.');
    }
    baseline.finance.requireIntegrity();
    await encryptedSession!.recycleVerifiedModule(
      baseline: baseline.encryptedWitness!,
      module: module,
      entityId: entityId,
      now: now,
      userConfirmed: true,
    );
    return await load(route: route);
  }

  Future<WaffraFinanceAuthorityRead> restoreVerifiedDeletedModule({
    required WaffraFinanceAuthorityRead baseline,
    required WaffraFinanceModule module,
    required String entityId,
    required DateTime now,
  }) async {
    final route = _verifiedModuleRoute(module);
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.encryptedWitness == null) {
      throw StateError('Verified encrypted module restore is not authorized.');
    }
    baseline.finance.requireIntegrity();
    await encryptedSession!.restoreVerifiedModule(
      baseline: baseline.encryptedWitness!,
      module: module,
      entityId: entityId,
      now: now,
    );
    return await load(route: route);
  }

  Future<Map<String, int>> listVerifiedDeletedModules(
    WaffraFinanceModule module,
  ) async {
    final route = _verifiedModuleRoute(module);
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Verified encrypted module trash is not available.');
    }
    return encryptedSession!.listVerifiedDeletedModules(module);
  }

  Future<WaffraFinanceAuthorityRead> load({
    required WaffraFinanceRoute route,
  }) async {
    final selected = await _requireRoute(route);
    if (selected == WaffraRuntimeFinanceBackend.guardedLegacy) {
      final loaded = await legacy.loadWithWitness();
      loaded.finance.requireIntegrity();
      return WaffraFinanceAuthorityRead(
        finance: loaded.finance,
        source: selected,
        widgetRevision: loaded.widgetRevision,
        ledgerRaw: loaded.ledgerRaw,
      );
    }
    // Underlying SQLCipher bridge independently rechecks durable witnesses
    // under native cross-engine file lock, not the caller's own boolean.
    final loaded = await encryptedSession!.loadForDashboardOrWidget();
    loaded.finance.requireIntegrity();
    return WaffraFinanceAuthorityRead(
      finance: loaded.finance,
      source: selected,
      widgetRevision: loaded.widgetRevision,
      ledgerRaw: loaded.ledgerRaw,
      encryptedWitness: loaded,
    );
  }

  /// The final destructive finance route deliberately has NO legacy
  /// implementation and no fallback to SharedPreferences. The caller must
  /// present the same fresh, independently attested SQLCipher read that is
  /// currently displayed and an externally saved authenticated backup.
  /// No UI shortcut is allowed to set the encrypted activation marker.
  Future<WaffraFinanceAuthorityRead> resetVerifiedFinance({
    required WaffraFinanceRoute route,
    required WaffraFinanceAuthorityRead baseline,
    required String encryptedBackup,
    required String backupPassword,
    required String confirmationPhrase,
    required bool userConfirmed,
    required bool biometricVerified,
    required bool externalBackupSaved,
  }) async {
    if (route != WaffraFinanceRoute.fullFinanceReset) {
      throw ArgumentError('Wrong route for full finance reset.');
    }
    if (!userConfirmed || !biometricVerified || !externalBackupSaved ||
        confirmationPhrase != WaffraEncryptedFullFinanceReset.confirmation) {
      throw StateError('Full reset requires biometric, external backup and approval.');
    }
    final source = await _requireRoute(route);
    if (source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        baseline.encryptedWitness == null) {
      throw StateError('Full reset requires an active, verified SQLCipher source.');
    }
    // Never allow a source switch between the approval UI and delete.
    final result = await encryptedSession!.resetVerifiedFinance(
      baseline: baseline.encryptedWitness!,
      encryptedBackup: encryptedBackup,
      backupPassword: backupPassword,
      confirmationPhrase: confirmationPhrase,
      userConfirmed: true,
      biometricVerified: true,
      externalBackupSaved: true,
    );
    if (result.newGeneration <= result.previousGeneration) {
      throw StateError('Encrypted full reset lacked a durable generation update.');
    }
    return load(route: route);
  }

  Future<WaffraFinanceAuthorityRead> saveCaptured({
    required WaffraFinanceRoute route,
    required WaffraFinanceAuthorityRead baseline,
    required Map<String, Object> captured,
    bool userConfirmed = false,
  }) async {
    // Capture caller-owned values synchronously, before ANY awaited source
    // probe. A queued Home edit can otherwise mutate the map while the OS
    // key / SQLCipher witness check is pending.
    final frozen = <String, Object>{};
    for (final item in captured.entries) {
      final v = item.value;
      frozen[item.key] = v is List<String>
          ? List<String>.unmodifiable(v) : v;
    }
    final immutableCapture = Map<String, Object>.unmodifiable(frozen);
    final backend = await _requireRoute(route);
    if (backend != baseline.source) {
      throw StateError('Finance authority changed while screen was open.');
    }
    // A second Paid tap with an already-posted deterministic ID must not be
    // reported as a successful scalar/no-op save. Postpone-only actions use
    // userConfirmed=false and are handled separately below.
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        route == WaffraFinanceRoute.recurringPostingAndPostponement &&
        userConfirmed &&
        (immutableCapture['entries'] is! String ||
         immutableCapture['entries'] ==
             baseline.encryptedWitness?.snapshot.values['entries'])) {
      throw StateError('This recurring payment has already been posted.');
    }
    // A recurring payment is NOT a scalar postponement edit. One confirmed
    // newly posted deterministic entry plus only its removed postponement
    // must pass through the combined normalized SQL/snapshot writer.
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        route == WaffraFinanceRoute.recurringPostingAndPostponement &&
        immutableCapture['entries'] is String &&
        baseline.encryptedWitness != null &&
        immutableCapture['entries'] !=
            baseline.encryptedWitness!.snapshot.values['entries']) {
      final witness = baseline.encryptedWitness!;
      if (!userConfirmed ||
          immutableCapture['waffra_recurring_postponed_v1'] is! String) {
        throw StateError('Recurring payment requires explicit user confirmation.');
      }
      for (final item in immutableCapture.entries) {
        if (item.key == 'entries' ||
            item.key == 'waffra_recurring_postponed_v1') {
          continue;
        }
        if (!witness.snapshot.values.containsKey(item.key) ||
            jsonEncode(item.value) !=
                jsonEncode(witness.snapshot.values[item.key])) {
          throw StateError('Recurring posting cannot include other finance edits.');
        }
      }
      List<Map<String, Object?>> ledger(String? raw) {
        final decoded = jsonDecode(raw ?? '[]');
        if (decoded is! List || decoded.any((x) => x is! Map)) {
          throw StateError('Recurring payment ledger is malformed.');
        }
        final ids = <String>{};
        final rows = <Map<String, Object?>>[];
        for (final entry in decoded) {
          final row = Map<String, Object?>.from(entry as Map);
          final id = row['id'];
          if (id is! String || id.trim().isEmpty || !ids.add(id)) {
            throw StateError('Recurring payment ledger has duplicate IDs.');
          }
          rows.add(row);
        }
        return rows;
      }
      final previous = ledger(witness.snapshot.values['entries'] as String?);
      final proposed = ledger(immutableCapture['entries'] as String);
      final byId = <String, Map<String, Object?>>{
        for (final row in previous) row['id'] as String: row,
      };
      final offered = <String, Map<String, Object?>>{
        for (final row in proposed) row['id'] as String: row,
      };
      final additions = proposed
          .where((row) => !byId.containsKey(row['id']))
          .toList(growable: false);
      if (proposed.length != previous.length + 1 ||
          additions.length != 1 ||
          byId.keys.any((id) =>
              !offered.containsKey(id) ||
              jsonEncode(byId[id]) != jsonEncode(offered[id]))) {
        throw StateError('Recurring posting may append only one immutable entry.');
      }
      await encryptedSession!.commitRecurringPayment(
        baseline: witness,
        record: additions.single,
        proposedPostponedJson:
            immutableCapture['waffra_recurring_postponed_v1'] as String,
        userConfirmed: true,
      );
      return await load(route: route);
    }
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        (route == WaffraFinanceRoute.challengeAndBudgetUpdate ||
         route == WaffraFinanceRoute.recurringPostingAndPostponement ||
         route == WaffraFinanceRoute.merchantRulesAndSmsHashes)) {
      final witness = baseline.encryptedWitness;
      if (witness == null) {
        throw StateError('Scalar finance edit requires an encrypted witness.');
      }
      // Typed projections already guard category budget writes. All other
      // allowlisted changes are strict JSON/scalar finance keys and use the
      // existing SQLCipher snapshot CAS within the shared Home/Widget lock.
      // Recurring PAYMENTS with a new transaction are NOT silently accepted:
      // they need an atomic entry+postponement posting writer separately.
      final allowed = switch (route) {
        WaffraFinanceRoute.challengeAndBudgetUpdate => <String>{
          'waffra_challenges_v1',
          'waffra_monthly_budget_v1',
          'waffra_monthly_budget_enabled_v1',
          'waffra_categories_v24',
        },
        WaffraFinanceRoute.recurringPostingAndPostponement => <String>{
          'waffra_recurring_postponed_v1',
        },
        WaffraFinanceRoute.merchantRulesAndSmsHashes => <String>{
          'waffra_learned_merchants_v1',
        },
        _ => const <String>{},
      };
      for (final item in immutableCapture.entries) {
        final previous = witness.snapshot.values;
        final changed = !previous.containsKey(item.key) ||
            jsonEncode(previous[item.key]) != jsonEncode(item.value);
        if (changed && !allowed.contains(item.key)) {
          throw StateError('Finance route contains unverified coupled edits.');
        }
      }
      final verifiedSession = encryptedSession!;
      await verifiedSession.saveDashboardBatch(
        baseline: witness,
        captured: immutableCapture,
      );
      return await load(route: route);
    }
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        route == WaffraFinanceRoute.deleteAllTransactions) {
      final witness = baseline.encryptedWitness;
      final expectedFields = immutableCapture.keys.toSet();
      if (!userConfirmed || witness == null ||
          expectedFields.length != 2 ||
          !expectedFields.contains('entries') ||
          !expectedFields.contains('waffra_sms_hashes_v1') ||
          immutableCapture['entries'] != '[]' ||
          immutableCapture['waffra_sms_hashes_v1'] is! List<String> ||
          (immutableCapture['waffra_sms_hashes_v1'] as List<String>).isNotEmpty) {
        throw StateError('Encrypted delete-all requires exact consent and scope.');
      }
      await encryptedSession!.deleteAllUnattachedTransactions(
        baseline: witness, userConfirmed: true,
      );
      return await load(route: route);
    }
    if (backend == WaffraRuntimeFinanceBackend.verifiedEncrypted &&
        route == WaffraFinanceRoute.manualTransactionSave) {
      // A manual form's full Home capture is NOT an authorization to replace
      // older finance data. Extract exactly one new record, preserve every
      // previous field and let the atomic SQLCipher entry writer append it
      // under the Widget lock. Reordering existing records is harmless.
      final witness = baseline.encryptedWitness;
      if (witness == null || immutableCapture['entries'] is! String) {
        throw StateError('Manual save requires its original encrypted witness.');
      }
      final original = witness.snapshot.values;
      for (final item in immutableCapture.entries) {
        if (item.key == 'entries') continue;
        if (!original.containsKey(item.key) ||
            jsonEncode(original[item.key]) != jsonEncode(item.value)) {
          throw StateError('Manual save includes unrelated finance edits.');
        }
      }
      List<Map<String, Object?>> parseLedger(String? raw) {
        final decoded = jsonDecode(raw ?? '[]');
        if (decoded is! List) {
          throw StateError('Manual finance ledger is malformed.');
        }
        final records = <Map<String, Object?>>[];
        final seen = <String>{};
        for (final row in decoded) {
          if (row is! Map || row['id'] is! String ||
              (row['id'] as String).trim().isEmpty ||
              !seen.add(row['id'] as String)) {
            throw StateError('Manual finance ledger has ambiguous IDs.');
          }
          records.add(Map<String, Object?>.from(row));
        }
        return records;
      }
      final before = parseLedger(original['entries'] as String?);
      final after = parseLedger(immutableCapture['entries'] as String);
      final prior = {for (final row in before) row['id'] as String: row};
      final next = {for (final row in after) row['id'] as String: row};
      final added = after.where((row) => !prior.containsKey(row['id']))
          .toList(growable: false);
      if (after.length != before.length + 1 || added.length != 1 ||
          prior.keys.any((id) =>
              !next.containsKey(id) ||
              jsonEncode(prior[id]) != jsonEncode(next[id]))) {
        throw StateError('Manual save may only append one unchanged transaction.');
      }
      await encryptedSession!.appendConfirmed(
        records: added,
        hashes: const <String?>[null],
        userConfirmed: true,
      );
      return await load(route: route);
    }
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      await legacy.saveLegacy(
        snapshot: immutableCapture,
        expectedLedgerRaw: baseline.ledgerRaw,
        expectedWidgetRevision: baseline.widgetRevision,
      );
    } else {
      // This branch cannot be selected by current production: independent
      // key recovery, route audit and dual activation witnesses are mandatory.
      // When a future release selects it, only proven, non-destructive editor
      // deltas may pass; deletes/resets/receipt mutations need separate writers.
      final witness = baseline.encryptedWitness;
      const projectedFields = <String>{
        'entries',
        'waffra_categories_v24',
        'waffra_goals_v24',
        'waffra_recurring_v24',
      };
      const projectedEditorRoutes = <WaffraFinanceRoute>{
        WaffraFinanceRoute.transactionEdit,
        WaffraFinanceRoute.categoryCreateEditDeleteRestore,
        WaffraFinanceRoute.goalCreateEditDeleteRestore,
        WaffraFinanceRoute.recurringCreateEditDeleteRestore,
      };
      final oldValues = witness?.snapshot.values;
      final unsupportedChange = oldValues == null ||
          immutableCapture.entries.any((item) {
            final changed = !oldValues.containsKey(item.key) ||
                jsonEncode(oldValues[item.key]) != jsonEncode(item.value);
            return changed && !projectedFields.contains(item.key);
          });
      if (witness == null ||
          !projectedEditorRoutes.contains(route) ||
          unsupportedChange) {
        throw StateError(
          'Encrypted screen mutation requires a verified atomic SQL projection writer.',
        );
      }
      // saveDashboardBatch derives a delta from the exact loaded witness.
      // The bridge checks the durable source under the shared native lock;
      // entry and module projection guards reconcile INSIDE its SQL transaction.
      // Changes to the same key made by the Widget cause a hard conflict.
      final session = encryptedSession!;
      await session.saveDashboardBatch(
        baseline: witness,
        captured: immutableCapture,
      );
    }
    // Never publish optimistic UI success before getting durable witness.
    return load(route: route);
  }

  /// A future encrypted-only receipt attachment route. The caller supplies
  /// picker bytes (never plaintext file paths) and explicitly confirms.
  /// The source selector and the SQLCipher bridge each independently verify
  /// the activated source before the atomic entry+receipt commit.
  ///
  /// Guarded legacy deliberately rejects this API: existing legacy receipt
  /// saving continues through its separately audited legacy writer.
  Future<WaffraEncryptedReceiptTransactionResult> commitWithReceiptBytes({
    required WaffraFinanceRoute route,
    required Map<String, Object?> record,
    required List<Uint8List> images,
    required bool userConfirmed,
    String? smsHash,
  }) async {
    if (route != WaffraFinanceRoute.receiptCopyAndAttach) {
      throw ArgumentError('Not a receipt attachment route.');
    }
    if (!userConfirmed) {
      throw StateError('Receipt attachment requires user confirmation.');
    }
    // Freeze caller-owned data before awaiting the source witness or lock.
    // Neither the widget nor a second picker callback may mutate a queued
    // confirmation while the OS is checking the encrypted source.
    final capturedRecord = Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(record)) as Map<String, dynamic>,
      ),
    );
    final capturedImages = List<Uint8List>.unmodifiable(
      images.map(Uint8List.fromList),
    );
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError(
        'Encrypted receipt attachment requires verified SQLCipher source.',
      );
    }
    return encryptedSession!.appendWithReceiptBytes(
      record: capturedRecord,
      images: capturedImages,
      userConfirmed: true,
      smsHash: smsHash,
    );
  }

  /// Replaces bytes for an existing image; deletion and undo remain blocked
  /// until an independently tested retention contract exists.
  Future<void> replaceEncryptedReceiptImage({
    required WaffraFinanceRoute route,
    required String entryId,
    required int position,
    required Uint8List image,
    required String expectedSha256,
  }) async {
    if (route != WaffraFinanceRoute.receiptCopyAndAttach ||
        entryId.trim().isEmpty || position < 0) {
      throw ArgumentError('Invalid encrypted receipt replacement route.');
    }
    final captured = Uint8List.fromList(image);
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Receipt replacement requires verified SQLCipher.');
    }
    return encryptedSession!.replaceReceiptImage(
      entryId: entryId,
      position: position,
      image: captured,
      expectedSha256: expectedSha256,
    );
  }

  /// Read an existing receipt from the SAME verified finance authority as
  /// the Home transaction list. No fallback to a legacy plaintext path.
  Future<List<Uint8List>> loadEncryptedReceiptImages({
    required WaffraFinanceRoute route,
    required String entryId,
  }) async {
    if (route != WaffraFinanceRoute.receiptView ||
        entryId.trim().isEmpty || entryId.length > 128) {
      throw ArgumentError('Invalid encrypted receipt read request.');
    }
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Encrypted receipt read requires verified SQLCipher.');
    }
    return encryptedSession!.readReceiptImages(entryId);
  }

  /// Only the independently verified encrypted source may service the
  /// encrypted image viewer. No SharedPreferences or file-path fallback.
  Future<WaffraReceiptScreenState> loadVerifiedReceiptScreen({
    required WaffraFinanceRoute route,
    required String entryId,
  }) async {
    if (route != WaffraFinanceRoute.receiptView ||
        entryId.trim().isEmpty || entryId.length > 128) {
      throw ArgumentError('Invalid verified receipt screen route.');
    }
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Verified SQLCipher receipt source is required.');
    }
    return encryptedSession!.loadReceiptScreen(entryId);
  }

  Future<WaffraReceiptRecycleResult> moveEncryptedReceiptBatchToRecycle({
    required WaffraFinanceRoute route,
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  }) async {
    if (route != WaffraFinanceRoute.receiptRemoveAndRollback) {
      throw ArgumentError('Wrong route for encrypted receipt recycle.');
    }
    if (!userConfirmed) {
      throw StateError('Receipt removal requires explicit user approval.');
    }
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Encrypted receipt removal needs verified SQLCipher.');
    }
    return encryptedSession!.moveReceiptBatchToRecycle(
      baseline: baseline, userConfirmed: true, now: now,
    );
  }

  Future<WaffraReceiptRecycleResult> restoreEncryptedReceiptBatchFromRecycle({
    required WaffraFinanceRoute route,
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  }) async {
    if (route != WaffraFinanceRoute.receiptRemoveAndRollback) {
      throw ArgumentError('Wrong route for encrypted receipt restore.');
    }
    final backend = await _requireRoute(route);
    if (backend != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      throw StateError('Encrypted receipt restore needs verified SQLCipher.');
    }
    return encryptedSession!.restoreReceiptBatchFromRecycle(
      baseline: baseline, now: now,
    );
  }

  Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms({
    required WaffraFinanceRoute route,
    required List<Map<String, Object?>> records,
    required List<String> hashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
    List<Map<String, Object?>> proposedCategories = const [],
  }) async {
    if (route != WaffraFinanceRoute.bulkSmsConfirmedSave &&
        route != WaffraFinanceRoute.widgetSmsConfirmedSave) {
      throw ArgumentError('Not a bank SMS confirmation route.');
    }
    if (!userConfirmed || records.isEmpty || records.length > 100 ||
        hashes.length != records.length) {
      throw StateError('Confirmed SMS batch must contain 1–100 records.');
    }
    // Freeze before any await. Never capture raw message/clipboard contents.
    final frozen = records.map((item) => Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(item)) as Map<String, dynamic>,
      ),
    )).toList(growable: false);
    final fingerprints = List<String>.unmodifiable(hashes);
    // Freeze every user-confirmed category before the first asynchronous
    // source check. Home/Widget may still rebuild or edit their category lists
    // while waiting for the native writer lock; the committed batch must not
    // silently change beneath the confirmation screen.
    if (proposedCategories.length > 100) {
      throw ArgumentError('Merchant category proposals exceed the SMS limit.');
    }
    final frozenCategories = List<Map<String, Object?>>.unmodifiable(
      proposedCategories.map((category) {
        final decoded = jsonDecode(jsonEncode(category));
        if (decoded is! Map<String, dynamic>) {
          throw ArgumentError('Invalid confirmed merchant category.');
        }
        return Map<String, Object?>.unmodifiable(decoded);
      }),
    );
    final backend = await _requireRoute(route);
    late final int saved, income, expenses, skipped, incomeMinor, expenseMinor;
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      // Save transaction metadata without original SMS text on unencrypted
      // SharedPreferences. Preserve the strict M207 fail-closed gate on the
      // locked writer itself. Never send raw notes to that journal.
      // Freeze immutable originals here; the legacy writer selects ONLY
      // confirmed nonduplicate IDs under the Home/Widget native writer lock.
      // The SQLCipher staging hook is then invoked before any plaintext
      // metadata journal is prepared. No skipped duplicate's bank text is
      // staged merely because it appeared in the original paste.
      final originalsById = <String, (Map<String, Object?>, String)>{};
      for (var i = 0; i < frozen.length; i++) {
        final id = frozen[i]['id'];
        if (id is! String || id.trim().isEmpty ||
            originalsById.containsKey(id)) {
          throw StateError('Ambiguous confirmed bank SMS entry ID.');
        }
        originalsById[id] = (frozen[i], fingerprints[i]);
      }
      final redacted = List<Map<String, Object?>>.unmodifiable(
        frozen.map((record) {
          if (record['sourceType'] != 'sms') {
            throw StateError('SMS confirmation requires an SMS source.');
          }
          return Map<String, Object?>.unmodifiable({...record, 'notes': ''});
        }),
      );
      final result = await legacy.commitConfirmedLegacySms(
        records: redacted, messageHashes: fingerprints,
        userConfirmed: true, allowDuplicateHashes: allowDuplicateHashes,
        proposedCategories: frozenCategories,
        protectedNotesBeforeLegacyCommit: protectedSmsNotes == null
            ? null
            : (confirmed, confirmedHashes) async {
                final originals = <Map<String, Object?>>[];
                for (var i = 0; i < confirmed.length; i++) {
                  final id = confirmed[i]['id'];
                  final matching = originalsById[id];
                  if (matching == null || matching.$2 != confirmedHashes[i]) {
                    throw StateError('Bank SMS/finance IDs changed under lock.');
                  }
                  originals.add(matching.$1);
                }
                await protectedSmsNotes!.stage(
                  records: originals, hashes: confirmedHashes);
              },
      );
      saved = result.added;
      income = result.savedIncome;
      expenses = result.savedExpenses;
      skipped = result.skippedDuplicates;
      incomeMinor = result.incomeMinor;
      expenseMinor = result.expenseMinor;
    } else {
      // The encrypted writer checks category snapshots and SQL projections
      // under the shared write lock and rolls back the whole SQL transaction.
      final result = await encryptedSession!.appendConfirmed(
        records: frozen, hashes: fingerprints.cast<String?>(),
        userConfirmed: true, allowDuplicateHashes: allowDuplicateHashes,
        proposedCategories: frozenCategories,
      );
      saved = result.saved;
      income = result.savedIncome;
      expenses = result.savedExpenses;
      skipped = result.skippedDuplicates;
      incomeMinor = result.incomeMinor;
      expenseMinor = result.expenseMinor;
    }
    return WaffraFinanceAuthoritySmsCommit(
      saved: saved, income: income, expenses: expenses,
      incomeMinor: incomeMinor, expenseMinor: expenseMinor,
      skippedDuplicates: skipped,
      originalSmsNotesOmittedOnLegacy:
          backend == WaffraRuntimeFinanceBackend.guardedLegacy &&
          protectedSmsNotes == null &&
          frozen.any((entry) => entry['notes'] != null && entry['notes'] != ''),
      current: await load(route: route),
    );
  }
}

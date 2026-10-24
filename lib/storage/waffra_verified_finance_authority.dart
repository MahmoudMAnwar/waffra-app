import 'dart:convert';
import 'dart:typed_data';

import 'waffra_encrypted_finance_session.dart';
import 'waffra_receipt_screen_contract.dart';
import 'waffra_encrypted_receipt_recycle.dart';
import 'waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'waffra_finance_read_view.dart';
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
  });
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
  });

  final WaffraHomeFinancePersistence legacy;
  final WaffraProductionFinanceSourceGuard sourceGuard;
  final WaffraEncryptedFinanceSession? encryptedSession;
  final WaffraFinanceRouteAudit audit;
  final bool encryptedSqlWitnessActive;
  final bool externalSourceWitnessActive;
  final bool verifiedKeyRecoveryInDevice;

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
    if (backend != WaffraRuntimeFinanceBackend.guardedLegacy) {
      throw StateError('Encrypted recurring reminder scalar is not certified.');
    }
    await legacy.setRecurringReminderPreference(enabled);
    return load(route: WaffraFinanceRoute.recurringCreateEditDeleteRestore);
  }

  /// Custom suggestions are outside the canonical encrypted finance snapshot
  /// today. Never read them from old preferences after source activation.
  Future<List<String>> loadCustomGoalSuggestions() async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    if (backend != WaffraRuntimeFinanceBackend.guardedLegacy) {
      throw StateError('Encrypted custom goal suggestions are not certified.');
    }
    return legacy.loadCustomGoalSuggestions();
  }

  Future<bool> addCustomGoalSuggestion(String name) async {
    final backend = await _requireRoute(
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    if (backend != WaffraRuntimeFinanceBackend.guardedLegacy) {
      throw StateError('Encrypted custom goal suggestions are not certified.');
    }
    return legacy.addCustomGoalSuggestion(name);
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
    if (backend != WaffraRuntimeFinanceBackend.guardedLegacy) {
      throw StateError('Encrypted catalog installation is not certified.');
    }
    await legacy.installCategoryCatalog(
      version: version,
      expectedCatalogRaw: expectedCatalogRaw,
      nextCatalogRaw: nextCatalogRaw,
      catalogChanged: catalogChanged,
    );
    return load(route: WaffraFinanceRoute.categoryCatalogInstall);
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

  Future<WaffraFinanceAuthorityRead> saveCaptured({
    required WaffraFinanceRoute route,
    required WaffraFinanceAuthorityRead baseline,
    required Map<String, Object> captured,
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
      final result = await legacy.commitConfirmedLegacySms(
        records: frozen, messageHashes: fingerprints,
        userConfirmed: true, allowDuplicateHashes: allowDuplicateHashes,
        proposedCategories: frozenCategories,
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
      current: await load(route: route),
    );
  }
}

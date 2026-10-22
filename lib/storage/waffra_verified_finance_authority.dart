import 'dart:convert';

import 'waffra_encrypted_finance_session.dart';
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
    final backend = await _requireRoute(route);
    if (backend != baseline.source) {
      throw StateError('Finance authority changed while screen was open.');
    }
    final frozen = <String, Object>{};
    for (final item in captured.entries) {
      final v = item.value;
      frozen[item.key] = v is List<String>
          ? List<String>.unmodifiable(v) : v;
    }
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      await legacy.saveLegacy(
        snapshot: Map<String, Object>.unmodifiable(frozen),
        expectedLedgerRaw: baseline.ledgerRaw,
        expectedWidgetRevision: baseline.widgetRevision,
      );
    } else {
      final witness = baseline.encryptedWitness;
      if (witness == null) {
        throw StateError('Verified encrypted baseline not available.');
      }
      await encryptedSession!.saveDashboardBatch(
        baseline: witness,
        captured: frozen,
      );
    }
    // Never publish optimistic UI success before getting durable witness.
    return load(route: route);
  }

  Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms({
    required WaffraFinanceRoute route,
    required List<Map<String, Object?>> records,
    required List<String> hashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
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
    final backend = await _requireRoute(route);
    late final int saved, income, expenses, skipped, incomeMinor, expenseMinor;
    if (backend == WaffraRuntimeFinanceBackend.guardedLegacy) {
      final result = await legacy.commitConfirmedLegacySms(
        records: frozen, messageHashes: fingerprints,
        userConfirmed: true, allowDuplicateHashes: allowDuplicateHashes,
      );
      saved = result.added;
      income = result.savedIncome;
      expenses = result.savedExpenses;
      skipped = result.skippedDuplicates;
      incomeMinor = result.incomeMinor;
      expenseMinor = result.expenseMinor;
    } else {
      final result = await encryptedSession!.appendConfirmed(
        records: frozen, hashes: fingerprints.cast<String?>(),
        userConfirmed: true, allowDuplicateHashes: allowDuplicateHashes,
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

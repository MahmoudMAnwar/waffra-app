import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_finance_24_route_preflight.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _AlwaysRecovery extends WaffraProductionFinanceSourceGuard {
  const _AlwaysRecovery();
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'M236_synthetic_recovery_stops_all_finance_routes',
  );
}

class _RefusingLegacy extends WaffraHomeFinancePersistence {
  _RefusingLegacy();
  var reads = 0;
  @override
  Future<WaffraHomeFinanceLoaded> loadWithWitness() async {
    reads++;
    throw StateError('Unverified fallback to legacy finance was attempted.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remaining = <WaffraFinanceRoute>[
    WaffraFinanceRoute.appStartup,
    WaffraFinanceRoute.widgetStartup,
    WaffraFinanceRoute.dashboardRead,
    WaffraFinanceRoute.widgetRead,
    WaffraFinanceRoute.manualTransactionSave,
    WaffraFinanceRoute.bulkSmsConfirmedSave,
    WaffraFinanceRoute.widgetSmsConfirmedSave,
    WaffraFinanceRoute.transactionEdit,
    WaffraFinanceRoute.transactionDeleteAndUndo,
    WaffraFinanceRoute.deleteAllTransactions,
    WaffraFinanceRoute.categoryCreateEditDeleteRestore,
    WaffraFinanceRoute.goalCreateEditDeleteRestore,
    WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    WaffraFinanceRoute.recurringPostingAndPostponement,
    WaffraFinanceRoute.challengeAndBudgetUpdate,
    WaffraFinanceRoute.merchantRulesAndSmsHashes,
    WaffraFinanceRoute.receiptRemoveAndRollback,
    WaffraFinanceRoute.widgetBalanceRefresh,
    WaffraFinanceRoute.backupRestore,
    WaffraFinanceRoute.fullFinanceReset,
  ];

  const inspected = <WaffraFinanceRoute, String>{
    WaffraFinanceRoute.appStartup: 'lib/main.dart',
    WaffraFinanceRoute.widgetStartup: 'lib/waffra_widget_capture.part.dart',
    WaffraFinanceRoute.dashboardRead: 'lib/main.dart',
    WaffraFinanceRoute.widgetRead: 'lib/waffra_widget_capture.part.dart',
    WaffraFinanceRoute.manualTransactionSave: 'lib/main.dart',
    WaffraFinanceRoute.bulkSmsConfirmedSave: 'lib/main.dart',
    WaffraFinanceRoute.widgetSmsConfirmedSave: 'lib/waffra_widget_capture.part.dart',
    WaffraFinanceRoute.transactionEdit: 'lib/main.dart',
    WaffraFinanceRoute.transactionDeleteAndUndo: 'lib/main.dart',
    WaffraFinanceRoute.deleteAllTransactions: 'lib/main.dart',
    WaffraFinanceRoute.categoryCreateEditDeleteRestore: 'lib/main.dart',
    WaffraFinanceRoute.goalCreateEditDeleteRestore: 'lib/main.dart',
    WaffraFinanceRoute.recurringCreateEditDeleteRestore: 'lib/main.dart',
    WaffraFinanceRoute.recurringPostingAndPostponement: 'lib/main.dart',
    WaffraFinanceRoute.challengeAndBudgetUpdate: 'lib/main.dart',
    WaffraFinanceRoute.merchantRulesAndSmsHashes: 'lib/storage/waffra_verified_finance_authority.dart',
    WaffraFinanceRoute.receiptRemoveAndRollback: 'lib/storage/waffra_verified_finance_authority.dart',
    WaffraFinanceRoute.widgetBalanceRefresh: 'lib/main.dart',
    WaffraFinanceRoute.backupRestore: 'lib/main.dart',
    WaffraFinanceRoute.fullFinanceReset: 'lib/main.dart',
  };

  const activeSynthetic = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'M236_disposable_only_not_production_attestation',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'M236_corrupt_or_unfinished_cutover',
  );

  WaffraFinanceRouteAudit audit(Set<WaffraFinanceRoute> selected) =>
      WaffraFinanceRouteAudit(
        verifiedRoutes: selected,
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      );

  test('M236 inventory exactly equals the twenty routes outside M235', () {
    final m235 = <WaffraFinanceRoute>{
      WaffraFinanceRoute.categoryCatalogInstall,
      WaffraFinanceRoute.receiptCopyAndAttach,
      WaffraFinanceRoute.receiptView,
      WaffraFinanceRoute.backupExport,
    };
    expect(WaffraFinanceRoute.values.length, 24);
    expect(remaining.length, 20);
    expect(remaining.toSet().length, 20);
    expect(remaining.toSet(),
        WaffraFinanceRoute.values.toSet().difference(m235));
    expect(inspected.keys.toSet(), remaining.toSet());
  });

  // Twenty separate named tests are dispatched by an explicit GitHub Actions
  // matrix. Each exercises its own route, its caller-boundary presence and
  // the zero-fallback contract. These do NOT assert that real SQL writes,
  // backup restore or physical phones have been certified.
  for (final route in remaining) {
    test('M236 ${route.name} source boundary and caller wiring QA only',
        () async {
      final path = inspected[route]!;
      final code = File(path).readAsStringSync();
      expect(code, contains('WaffraFinanceRoute.${route.name}'),
          reason: 'Missing runtime callsite for ${route.name} at $path');

      // A recovery or partial cutover must never allow this route to touch
      // legacy keys, create a new source key, or show a fabricated balance.
      final legacy = _RefusingLegacy();
      final authority = WaffraVerifiedFinanceAuthority(
        sourceGuard: const _AlwaysRecovery(),
        legacy: legacy,
      );
      await expectLater(authority.load(route: route), throwsStateError);
      expect(legacy.reads, 0);

      final selected = WaffraFinanceRoute.values.toSet()..remove(route);
      final denied = const WaffraFinance24RoutePreflight().inspect(
        source: activeSynthetic,
        audit: audit(selected),
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: true,
      );
      expect(denied.missingAuditRoutes, [route]);
      expect(denied.allContractsAcceptEncrypted, isFalse);
      expect(denied.routes[route], WaffraRouteSourceOutcome.blocked);
      expect(denied.productionCutoverAuthorized, isFalse);

      // Missing OS-keystore recovery evidence is a fatal global barrier.
      final noKey = const WaffraFinance24RoutePreflight().inspect(
        source: activeSynthetic,
        audit: audit(WaffraFinanceRoute.values.toSet()),
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: false,
      );
      expect(noKey.routes[route], WaffraRouteSourceOutcome.blocked);
      expect(noKey.allContractsAcceptEncrypted, isFalse);

      // The actual route contract must reject recovery, regardless of any
      // synthetic all-green selection flags or a Fake Home/Widget preference.
      final selection = WaffraRuntimeFinanceRouteContract(
        source: recovery,
        audit: audit(WaffraFinanceRoute.values.toSet()),
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: true,
      );
      expect(() => selection.requireRoute(route), throwsStateError);
      expect(const WaffraProductionCutoverDecision([])
          .automaticallyActivateSqlCipher, isFalse);
    });
  }
}

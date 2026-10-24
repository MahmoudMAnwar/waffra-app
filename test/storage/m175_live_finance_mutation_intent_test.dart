import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

/// Static wiring proof plus negative selection tests. Does not change the
/// production storage source or attempt to open a user-owned SQLCipher vault.
void main() {
  final routedIntents = <WaffraFinanceRoute>[
    WaffraFinanceRoute.manualTransactionSave,
    WaffraFinanceRoute.transactionEdit,
    WaffraFinanceRoute.transactionDeleteAndUndo,
    WaffraFinanceRoute.recurringPostingAndPostponement,
  ];

  test('M175 exact Home live writes carry their distinct finance intent', () {
    final home = File('lib/main.dart').readAsStringSync();
    expect(home, contains(
      'WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit,'));
    expect(home, contains('route:route,\n    baseline:baseline,'));
    expect(home, contains(
      'await persist(route:initial==null\n'
      '   ?WaffraFinanceRoute.manualTransactionSave\n'
      '   :WaffraFinanceRoute.transactionEdit);'));
    expect(home, contains(
      'await persist(route:WaffraFinanceRoute.transactionDeleteAndUndo);'));
    expect(home, contains(
      'await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement);'));
    expect(
      'await persist(route:WaffraFinanceRoute.transactionDeleteAndUndo);'
        .allMatches(home).length,
      2, reason: 'Both delete AND undo must be tagged.',
    );
    expect(
      'await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement);'
        .allMatches(home).length,
      1, reason: 'Only the postpone-only action uses the scalar path.',
    );
    expect(
      'await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,'
        .allMatches(home).length,
      1, reason: 'The Paid path must retain its recurring route intent.',
    );
    expect(home, contains(
      'await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,'
      '\n      userConfirmed:true);'
    ), reason: 'Paid requires explicit user confirmation.');
  });

  test('M175 guarded legacy routes remain eligible, without any cutover', () {
    const report = WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.guardedLegacy,
      reasonCode: 'legacy_source_verified',
    );
    final contract = WaffraRuntimeFinanceRouteContract(
      source: report, audit: const WaffraFinanceRouteAudit(),
    );
    for (final route in routedIntents) {
      expect(contract.requireRoute(route),
        WaffraRuntimeFinanceBackend.guardedLegacy);
    }
  });

  test('M175 incomplete SQLCipher route witness fails closed per intent', () {
    const report = WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.encryptedRoutingRequired,
      reasonCode: 'all_live_writers_not_yet_routed',
    );
    final contract = WaffraRuntimeFinanceRouteContract(
      source: report,
      audit: const WaffraFinanceRouteAudit(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    for (final route in routedIntents) {
      expect(() => contract.requireRoute(route), throwsStateError,
        reason: 'No live write may bypass independently verified route audit.');
    }
  });

  test('M175 active SQL source report cannot write guarded legacy', () {
    const report = WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.encryptedRoutingRequired,
      reasonCode: 'all_live_writers_not_yet_routed',
    );
    for (final route in routedIntents) {
      expect(() => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
        report: report,
        route: route,
      ), throwsStateError);
    }
  });
}

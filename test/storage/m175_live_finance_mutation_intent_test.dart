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
    // Retain exact finance route selection while allowing safe formatting
    // changes around a verified-confirmation feedback wrapper.
    expect(RegExp(
      r'await persist\(route:initial==null\s+'
      r'\?WaffraFinanceRoute\.manualTransactionSave\s+'
      r':WaffraFinanceRoute\.transactionEdit\);',
    ).hasMatch(home),isTrue);
    // Delete, undo and postponement now use the same fail-closed wrapper
    // rather than unguarded direct persistence. Preserve the precise route
    // intent AND a fresh read after a rejected authoritative write.
    expect(home, contains('Future<bool> _persistModuleOrReload('));
    expect(home, contains('await persist(route:route);'));
    expect(home, contains('if(mounted)await _loadFinanceSafely();'));
    for(final action in <String>['transaction-delete','transaction-undo']) {
      expect(RegExp(
        r'if\(!await _persistModuleOrReload\(\s*'
        r'WaffraFinanceRoute\.transactionDeleteAndUndo,\s*'
        "operation:'"+action+r"'\)\)return;"
      ).hasMatch(home), isTrue,reason:'Missing guarded '+action+' route');
    }
    expect(RegExp(
      r'if\(!await _persistModuleOrReload\(\s*'
      r'WaffraFinanceRoute\.recurringPostingAndPostponement,\s*'
      r"operation:'recurring-postpone'\)\)return;"
    ).hasMatch(home), isTrue, reason:'Postpone needs a guarded route');
    expect(
      'WaffraFinanceRoute.transactionDeleteAndUndo,'
        .allMatches(home).length, greaterThanOrEqualTo(2),
      reason: 'Both delete and undo must be tagged separately.',
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

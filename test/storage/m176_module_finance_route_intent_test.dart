import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

/// M176 is source-provenance only. All runtime fixtures are synthetic:
/// no preferences are changed, no SQL vault is opened and no user data exists.
void main() {
  final intents = <WaffraFinanceRoute>[
    WaffraFinanceRoute.categoryCreateEditDeleteRestore,
    WaffraFinanceRoute.goalCreateEditDeleteRestore,
    WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    WaffraFinanceRoute.challengeAndBudgetUpdate,
  ];

  test('M176 every existing category, goal, recurring and budget save is tagged', () {
    final home = File('lib/main.dart').readAsStringSync();
    final trash = File('lib/waffra_recurring_trash.part.dart').readAsStringSync();
    const routeCountsInHome = <String, int>{
      'categoryCreateEditDeleteRestore': 10,
      'goalCreateEditDeleteRestore': 6,
      'recurringCreateEditDeleteRestore': 3,
      'challengeAndBudgetUpdate': 4,
    };
    for (final entry in routeCountsInHome.entries) {
      final tag = 'persist(route:WaffraFinanceRoute.${entry.key})';
      expect(tag.allMatches(home).length, entry.value,
        reason: 'Every reviewed Home finance write needs its own source intent');
    }
    expect('persist(route:WaffraFinanceRoute.recurringCreateEditDeleteRestore)'
      .allMatches(trash).length, 3,
      reason: 'Recurring recycle expiry, restore and permanent delete need the same source lock');
    expect(home, contains('await persist(route:initial==null'));
    expect(home, contains('WaffraFinanceRoute.manualTransactionSave'));
    expect(home, contains('WaffraFinanceRoute.transactionDeleteAndUndo'));
    expect(home, contains('WaffraFinanceRoute.backupRestore'));
    expect(home, contains('WaffraFinanceRoute.fullFinanceReset'));
  });

  test('M176 all module mutation intents continue using guarded legacy safely', () {
    const source = WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.guardedLegacy,
      reasonCode: 'legacy_source_verified',
    );
    const contract = WaffraRuntimeFinanceRouteContract(
      source: source, audit: WaffraFinanceRouteAudit(),
    );
    for (final intent in intents) {
      expect(contract.requireRoute(intent),
        WaffraRuntimeFinanceBackend.guardedLegacy);
    }
  });

  test('M176 every proposed encrypted module route blocks without independent proof', () {
    const source = WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.encryptedRoutingRequired,
      reasonCode: 'all_live_writers_not_yet_routed',
    );
    const contract = WaffraRuntimeFinanceRouteContract(
      source: source, audit: WaffraFinanceRouteAudit(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    for (final intent in intents) {
      expect(() => contract.requireRoute(intent), throwsStateError,
        reason: 'A module intent cannot inherit fake transactionEdit approval');
      expect(() => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
        report: source, route: intent,
      ), throwsStateError, reason: 'Never fall back to old preferences');
    }
  });

  test('M176 route tagging never authorizes full finance production cutover', () {
    const audit = WaffraFinanceRouteAudit();
    for (final intent in intents) {
      expect(audit.blockers, contains('unverified_route_${intent.name}'));
    }
    final home = File('lib/main.dart').readAsStringSync();
    expect(home, contains('Future<void> persist({'));
    expect(home, contains('final baseline=_lastFinanceAuthorityRead;'));
    expect(home, contains('_financialWriteQueue.submit(snapshot,'));
    expect(home, contains('route:route,'));
    expect(home, isNot(contains('automaticallyActivateSqlCipher => true')));
  });
}

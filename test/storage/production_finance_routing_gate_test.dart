import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

void main() {
  test('M75 every finance route needs independent verification', () {
    const audit = WaffraFinanceRouteAudit();
    expect(audit.eligibleForIndependentReview, isFalse);
    expect(
      audit.blockers.where((b) => b.startsWith('unverified_route_')).length,
      WaffraFinanceRoute.values.length,
    );
  });

  test('M75 any one missing writer blocks the route audit', () {
    final all = WaffraFinanceRoute.values.toSet();
    for (final route in WaffraFinanceRoute.values) {
      final audit = WaffraFinanceRouteAudit(
        verifiedRoutes: all.difference({route}),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      );
      expect(audit.eligibleForIndependentReview, isFalse);
      expect(audit.blockers, contains('unverified_route_${route.name}'));
    }
  });

  test('M75 route coverage alone never replaces recovery proof', () {
    final audit = WaffraFinanceRouteAudit(
      verifiedRoutes: WaffraFinanceRoute.values.toSet(),
    );
    expect(audit.blockers, contains('encrypted_key_recovery_unverified'));
    expect(audit.blockers, contains('receipt_rollback_unverified'));
    expect(audit.blockers, contains('app_widget_lock_unverified'));
  });

  test('M75 app and widget both refuse encrypted or recovery-required routes', () {
    for (final route in [
      WaffraFinanceRoute.appStartup,
      WaffraFinanceRoute.widgetStartup,
    ]) {
      for (final source in [
        WaffraProductionFinanceSource.encryptedRoutingRequired,
        WaffraProductionFinanceSource.manualRecoveryRequired,
      ]) {
        expect(
          () => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
            report: WaffraProductionFinanceSourceReport(
              source: source, reasonCode: 'source_not_verified',
            ),
            route: route,
          ),
          throwsA(isA<StateError>()),
        );
      }
      expect(
        () => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
          report: const WaffraProductionFinanceSourceReport(
            source: WaffraProductionFinanceSource.guardedLegacy,
            reasonCode: 'legacy_source_verified',
          ),
          route: route,
        ),
        returnsNormally,
      );
    }
  });

  test('M75 even full synthetic evidence is review only', () {
    final audit = WaffraFinanceRouteAudit(
      verifiedRoutes: WaffraFinanceRoute.values.toSet(),
      keyRecoveryVerified: true,
      twoWitnessRecoveryVerified: true,
      receiptRollbackVerified: true,
      backupRestoreVerified: true,
      crossEngineLockVerified: true,
      legacyParityVerified: true,
    );
    expect(audit.blockers, isEmpty);
    expect(audit.eligibleForIndependentReview, isTrue);
  });
}

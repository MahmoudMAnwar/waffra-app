import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

/// M90 safe-by-default route audit: neither this suite nor the audit API
/// activates the SQLCipher source or touches production finance.
void main() {
  const all = WaffraFinanceRoute.values;

  test('M90 every finance path is independently tracked in the release audit',
      () {
    const draft = WaffraFinanceRouteAudit();
    expect(all.length, greaterThanOrEqualTo(20));
    expect(draft.verifiedRoutes, isEmpty);
    expect(draft.blockers
        .where((b) => b.startsWith('unverified_route_')).length, all.length);
    for (final route in all) {
      expect(draft.blockers, contains('unverified_route_${route.name}'));
    }
    expect(draft.eligibleForIndependentReview, isFalse);
  });

  test('M90 omission of any one writer blocks production review independently',
      () {
    for (final absent in all) {
      final audit = WaffraFinanceRouteAudit(
        verifiedRoutes: all.toSet().difference({absent}),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      );
      expect(audit.eligibleForIndependentReview, isFalse);
      expect(audit.blockers, ['unverified_route_${absent.name}']);
    }
  });

  test('M90 encrypted and recovery-required states block all 24 finance paths',
      () {
    for (final route in all) {
      for (final source in [
        WaffraProductionFinanceSource.encryptedRoutingRequired,
        WaffraProductionFinanceSource.manualRecoveryRequired,
      ]) {
        expect(
          () => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
            report: WaffraProductionFinanceSourceReport(
              source: source, reasonCode: 'm90_private_safe_diagnostic',
            ),
            route: route,
          ),
          throwsA(isA<StateError>()),
          reason: '${route.name} may never bypass source recovery',
        );
      }
    }
  });

  test('M90 verified guarded legacy remains permitted across listed routes',
      () {
    for (final route in all) {
      expect(
        () => WaffraProductionFinanceRoutingGate.requireGuardedLegacyReport(
          report: const WaffraProductionFinanceSourceReport(
            source: WaffraProductionFinanceSource.guardedLegacy,
            reasonCode: 'legacy_source_verified',
          ),
          route: route,
        ), returnsNormally,
      );
    }
  });

  test('M90 all route proof alone never substitutes missing key and rollback',
      () {
    final audit = WaffraFinanceRouteAudit(verifiedRoutes: all.toSet());
    expect(audit.eligibleForIndependentReview, isFalse);
    expect(audit.blockers, containsAll([
      'encrypted_key_recovery_unverified',
      'two_witness_recovery_unverified',
      'receipt_rollback_unverified',
      'backup_restore_unverified',
      'app_widget_lock_unverified',
      'legacy_finance_parity_unverified',
    ]));
  });
}

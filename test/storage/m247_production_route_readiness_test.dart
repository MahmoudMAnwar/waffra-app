import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

void main() {
  test('M247 production readiness fails closed for all 24 until independently attested', () {
    final routes = WaffraFinanceRoute.values.toSet();
    expect(routes.length, 24);
    final audit = WaffraFinanceRouteAudit(verifiedRoutes: routes);
    expect(audit.eligibleForIndependentReview, isFalse);
    expect(audit.blockers, containsAll(<String>[
      'encrypted_key_recovery_unverified',
      'two_witness_recovery_unverified',
      'receipt_rollback_unverified',
      'backup_restore_unverified',
      'app_widget_lock_unverified',
      'legacy_finance_parity_unverified',
    ]));
    final allFlags = WaffraFinanceRouteAudit(
      verifiedRoutes: routes,
      keyRecoveryVerified: true,
      twoWitnessRecoveryVerified: true,
      receiptRollbackVerified: true,
      backupRestoreVerified: true,
      crossEngineLockVerified: true,
      legacyParityVerified: true,
    );
    expect(allFlags.eligibleForIndependentReview, isTrue);
    // Review eligibility is intentionally NOT a source-activation operation.
  });
}

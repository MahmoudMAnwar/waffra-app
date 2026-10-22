import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';

void main() {
  const gate = WaffraProductionCutoverReleaseGate();

  WaffraCutoverReadinessReport storage({List<String> blockers = const []}) =>
      WaffraCutoverReadinessReport(
        sourceDigest: 'synthetic-only', blockers: blockers,
      );

  WaffraFinanceRouteAudit routes({bool complete = false}) =>
      WaffraFinanceRouteAudit(
        verifiedRoutes: complete
            ? WaffraFinanceRoute.values.toSet()
            : const <WaffraFinanceRoute>{},
        keyRecoveryVerified: complete,
        twoWitnessRecoveryVerified: complete,
        receiptRollbackVerified: complete,
        backupRestoreVerified: complete,
        crossEngineLockVerified: complete,
        legacyParityVerified: complete,
      );

  test('M123 default blocks activation even after green storage tests', () {
    final decision = gate.inspect(WaffraProductionCutoverEvidence(
      storage: storage(),
      routes: routes(complete: true),
    ));
    expect(decision.eligibleForHumanReleaseReview, false);
    expect(decision.blockers, contains('account_deletion_unverified'));
    expect(decision.blockers, contains('privacy_policy_unpublished'));
    expect(decision.blockers, contains('two_physical_devices_restore_unverified'));
    expect(decision.blockers, contains('receipt_expiry_clock_untrusted'));
    expect(decision.blockers, contains('human_release_approval_missing'));
    expect(decision.automaticallyActivateSqlCipher, false);
  });

  test('M123 missing any finance route blocks release', () {
    final decision = gate.inspect(WaffraProductionCutoverEvidence(
      storage: storage(),
      routes: routes(),
      accountDeletionVerified: true,
      privacyPolicyPublished: true,
      firebaseDataSafetyReviewed: true,
      crashReportingVerified: true,
      signedAndroidDeviceVerified: true,
      twoPhysicalDevicesRestoreVerified: true,
      expiryClockTrusted: true,
      explicitHumanApproval: true,
    ));
    expect(decision.blockers, contains('route_unverified_route_widgetStartup'));
    expect(decision.blockers, contains('route_unverified_route_receiptView'));
    expect(decision.eligibleForHumanReleaseReview, false);
  });

  test('M123 failed finance parity blocks all-green release', () {
    final decision = gate.inspect(WaffraProductionCutoverEvidence(
      storage: storage(blockers: ['encrypted_finance_parity_missing']),
      routes: routes(complete: true),
      accountDeletionVerified: true,
      privacyPolicyPublished: true,
      firebaseDataSafetyReviewed: true,
      crashReportingVerified: true,
      signedAndroidDeviceVerified: true,
      twoPhysicalDevicesRestoreVerified: true,
      expiryClockTrusted: true,
      explicitHumanApproval: true,
    ));
    expect(decision.blockers,
        contains('storage_encrypted_finance_parity_missing'));
    expect(decision.eligibleForHumanReleaseReview, false);
  });

  test('M123 complete synthetic evidence only permits human review', () {
    final decision = gate.inspect(WaffraProductionCutoverEvidence(
      storage: storage(),
      routes: routes(complete: true),
      accountDeletionVerified: true,
      privacyPolicyPublished: true,
      firebaseDataSafetyReviewed: true,
      crashReportingVerified: true,
      signedAndroidDeviceVerified: true,
      twoPhysicalDevicesRestoreVerified: true,
      expiryClockTrusted: true,
      explicitHumanApproval: true,
    ));
    expect(decision.blockers, isEmpty);
    expect(decision.eligibleForHumanReleaseReview, true);
    expect(decision.automaticallyActivateSqlCipher, false);
  });
}

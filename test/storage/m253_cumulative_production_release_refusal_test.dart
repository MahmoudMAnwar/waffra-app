import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

void main() {
  test('M253 combined M248-M252 does not constitute production evidence', () {
    // Even complete *structural* 24-route coverage cannot impersonate
    // physical on-device key/restore provenance or grant a live cutover.
    expect(WaffraFinanceRoute.values.length, 24);
    final result = const WaffraProductionCutoverReleaseGate().inspect(
      WaffraProductionCutoverEvidence(
        storage: const WaffraCutoverReadinessReport(
          sourceDigest: 'fixture-only-not-a-live-source',
          blockers: <String>['device_recovery_not_attested'],
        ),
        routes: WaffraFinanceRouteAudit(
          verifiedRoutes: WaffraFinanceRoute.values.toSet(),
        ),
      ),
    );
    expect(result.eligibleForHumanReleaseReview, isFalse);
    expect(result.automaticallyActivateSqlCipher, isFalse);
    expect(result.blockers, containsAll(<String>[
      'storage_device_recovery_not_attested',
      'route_encrypted_key_recovery_unverified',
      'route_two_witness_recovery_unverified',
      'route_receipt_rollback_unverified',
      'route_backup_restore_unverified',
      'route_app_widget_lock_unverified',
      'route_legacy_finance_parity_unverified',
      'signed_android_device_unverified',
      'two_physical_devices_restore_unverified',
      'account_deletion_unverified',
      'privacy_policy_unpublished',
      'firebase_data_safety_unreviewed',
      'crash_reporting_unverified',
      'receipt_expiry_clock_untrusted',
      'human_release_approval_missing',
    ]));
  });

  test('M253 even a synthetic fully green checklist never activates SQLCipher', () {
    final eligible = const WaffraProductionCutoverReleaseGate().inspect(
      WaffraProductionCutoverEvidence(
        storage: const WaffraCutoverReadinessReport(
          sourceDigest: 'fixture-not-production',
          blockers: <String>[],
        ),
        routes: WaffraFinanceRouteAudit(
          verifiedRoutes: WaffraFinanceRoute.values.toSet(),
          keyRecoveryVerified: true,
          twoWitnessRecoveryVerified: true,
          receiptRollbackVerified: true,
          backupRestoreVerified: true,
          crossEngineLockVerified: true,
          legacyParityVerified: true,
        ),
        accountDeletionVerified: true,
        privacyPolicyPublished: true,
        firebaseDataSafetyReviewed: true,
        crashReportingVerified: true,
        signedAndroidDeviceVerified: true,
        twoPhysicalDevicesRestoreVerified: true,
        expiryClockTrusted: true,
        explicitHumanApproval: true,
      ),
    );
    expect(eligible.eligibleForHumanReleaseReview, isTrue);
    expect(eligible.automaticallyActivateSqlCipher, isFalse);
  });
}

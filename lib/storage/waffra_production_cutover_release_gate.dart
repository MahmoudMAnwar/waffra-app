import 'waffra_cutover_readiness_gate.dart';
import 'waffra_production_finance_routing_gate.dart';

/// A release-level witness, not a user-facing feature flag.
///
/// Synthetic green tests do not prove real device backup, account deletion,
/// widget writer routing or production Firebase privacy compliance. These
/// require independent signed-off evidence and are deliberately not inferred
/// from CI success.
class WaffraProductionCutoverEvidence {
  const WaffraProductionCutoverEvidence({
    required this.storage,
    required this.routes,
    this.accountDeletionVerified = false,
    this.privacyPolicyPublished = false,
    this.firebaseDataSafetyReviewed = false,
    this.crashReportingVerified = false,
    this.signedAndroidDeviceVerified = false,
    this.twoPhysicalDevicesRestoreVerified = false,
    this.expiryClockTrusted = false,
    this.explicitHumanApproval = false,
  });

  final WaffraCutoverReadinessReport storage;
  final WaffraFinanceRouteAudit routes;
  final bool accountDeletionVerified;
  final bool privacyPolicyPublished;
  final bool firebaseDataSafetyReviewed;
  final bool crashReportingVerified;
  final bool signedAndroidDeviceVerified;
  final bool twoPhysicalDevicesRestoreVerified;
  final bool expiryClockTrusted;
  final bool explicitHumanApproval;
}

class WaffraProductionCutoverDecision {
  const WaffraProductionCutoverDecision(this.blockers);

  final List<String> blockers;
  bool get eligibleForHumanReleaseReview => blockers.isEmpty;

  /// Even a green review does NOT perform the source switch. An independent
  /// authorized deployment step is still mandatory.
  bool get automaticallyActivateSqlCipher => false;
}

class WaffraProductionCutoverReleaseGate {
  const WaffraProductionCutoverReleaseGate();

  WaffraProductionCutoverDecision inspect(
    WaffraProductionCutoverEvidence evidence,
  ) {
    final blockers = <String>[
      ...evidence.storage.blockers.map((reason) => 'storage_$reason'),
      ...evidence.routes.blockers.map((reason) => 'route_$reason'),
      if (!evidence.accountDeletionVerified) 'account_deletion_unverified',
      if (!evidence.privacyPolicyPublished) 'privacy_policy_unpublished',
      if (!evidence.firebaseDataSafetyReviewed) 'firebase_data_safety_unreviewed',
      if (!evidence.crashReportingVerified) 'crash_reporting_unverified',
      if (!evidence.signedAndroidDeviceVerified) 'signed_android_device_unverified',
      if (!evidence.twoPhysicalDevicesRestoreVerified)
        'two_physical_devices_restore_unverified',
      if (!evidence.expiryClockTrusted) 'receipt_expiry_clock_untrusted',
      if (!evidence.explicitHumanApproval) 'human_release_approval_missing',
    ];
    return WaffraProductionCutoverDecision(
      List<String>.unmodifiable(blockers.toSet()),
    );
  }
}

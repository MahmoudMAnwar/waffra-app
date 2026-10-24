import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

/// M173 only creates synthetic source reports; it never reads a real user's
/// finances, opens a database, requests Firebase or switches the app source.
void main() {
  const release = WaffraProductionCutoverReleaseGate();

  WaffraFinanceRouteAudit routesExcept(WaffraFinanceRoute? excluded) =>
      WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values
            .where((route) => route != excluded).toSet(),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      );

  WaffraProductionCutoverEvidence evidence({
    required WaffraFinanceRouteAudit routes,
    bool realDevice = false,
    bool twoPhones = false,
    bool deletion = false,
    bool privacy = false,
    bool dataSafety = false,
    bool crashes = false,
    bool expiryClock = false,
    bool humanApproval = false,
  }) =>
      WaffraProductionCutoverEvidence(
        storage: const WaffraCutoverReadinessReport(
          sourceDigest: 'M173-only-synthetic-evidence',
          blockers: [],
        ),
        routes: routes,
        accountDeletionVerified: deletion,
        privacyPolicyPublished: privacy,
        firebaseDataSafetyReviewed: dataSafety,
        crashReportingVerified: crashes,
        signedAndroidDeviceVerified: realDevice,
        twoPhysicalDevicesRestoreVerified: twoPhones,
        expiryClockTrusted: expiryClock,
        explicitHumanApproval: humanApproval,
      );

  const sourceReady = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );

  test('M173 exactly 24 source routes must be reviewed before cutover', () {
    expect(WaffraFinanceRoute.values, hasLength(24));
    final reviewed = routesExcept(null);
    expect(reviewed.blockers, isEmpty);
    final contract = WaffraRuntimeFinanceRouteContract(
      source: sourceReady,
      audit: reviewed,
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    // The isolated route contract can be satisfied by synthetic flags, but
    // production approval below NEVER infers device/server proof from it.
    expect(contract.requireAllLiveRoutes, returnsNormally);

    final decision = release.inspect(evidence(routes: reviewed));
    expect(decision.eligibleForHumanReleaseReview, isFalse);
    expect(decision.automaticallyActivateSqlCipher, isFalse);
    expect(decision.blockers, contains('signed_android_device_unverified'));
    expect(decision.blockers,
        contains('two_physical_devices_restore_unverified'));
    expect(decision.blockers, contains('account_deletion_unverified'));
    expect(decision.blockers, contains('privacy_policy_unpublished'));
  });

  test('M173 missing each of 24 financial routes independently blocks release',
      () {
    for (final route in WaffraFinanceRoute.values) {
      final audit = routesExcept(route);
      expect(audit.blockers, contains('unverified_route_${route.name}'));
      final runtime = WaffraRuntimeFinanceRouteContract(
        source: sourceReady,
        audit: audit,
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: true,
      );
      expect(() => runtime.requireRoute(route), throwsStateError,
          reason: 'Missing route ${route.name} must fail closed');
      final decision = release.inspect(evidence(
        routes: audit,
        realDevice: true,
        twoPhones: true,
        deletion: true,
        privacy: true,
        dataSafety: true,
        crashes: true,
        expiryClock: true,
        humanApproval: true,
      ));
      expect(decision.blockers,
          contains('route_unverified_route_${route.name}'));
      expect(decision.eligibleForHumanReleaseReview, false);
      expect(decision.automaticallyActivateSqlCipher, false);
    }
  });

  test('M173 missing physical Android proof cannot be waived by synthetic CI',
      () {
    final decision = release.inspect(evidence(
      routes: routesExcept(null),
      twoPhones: true,
      deletion: true,
      privacy: true,
      dataSafety: true,
      crashes: true,
      expiryClock: true,
      humanApproval: true,
    ));
    expect(decision.blockers, ['signed_android_device_unverified']);
    expect(decision.eligibleForHumanReleaseReview, false);
    expect(decision.automaticallyActivateSqlCipher, false);
  });

  test('M173 missing independent two-phone restore is a hard blocker', () {
    final decision = release.inspect(evidence(
      routes: routesExcept(null),
      realDevice: true,
      deletion: true,
      privacy: true,
      dataSafety: true,
      crashes: true,
      expiryClock: true,
      humanApproval: true,
    ));
    expect(decision.blockers, ['two_physical_devices_restore_unverified']);
    expect(decision.eligibleForHumanReleaseReview, false);
  });

  test('M173 a fictional all-green checklist NEVER performs production cutover',
      () {
    final decision = release.inspect(evidence(
      routes: routesExcept(null),
      realDevice: true,
      twoPhones: true,
      deletion: true,
      privacy: true,
      dataSafety: true,
      crashes: true,
      expiryClock: true,
      humanApproval: true,
    ));
    expect(decision.eligibleForHumanReleaseReview, true);
    expect(decision.automaticallyActivateSqlCipher, false);
  });

  test('M173 no incomplete SQL source witness can bypass finance guard', () {
    for (final sqlWitness in [false, true]) {
      for (final externalWitness in [false, true]) {
        for (final keyVerified in [false, true]) {
          final source = WaffraRuntimeFinanceRouteContract(
            source: sourceReady,
            audit: routesExcept(null),
            encryptedSqlWitnessActive: sqlWitness,
            externalSourceWitnessActive: externalWitness,
            verifiedKeyRecoveryInDevice: keyVerified,
          );
          final complete = sqlWitness && externalWitness && keyVerified;
          if (!complete) {
            expect(source.requireAllLiveRoutes, throwsStateError);
          } else {
            expect(source.requireAllLiveRoutes, returnsNormally);
          }
        }
      }
    }
  });
}

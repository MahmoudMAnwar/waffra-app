import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/cloud_sync_gate.dart';

void main() {
  WaffraSyncEligibility gate({
    bool consent = false,
    String? uid,
    String? owner,
    bool recovery = false,
    bool region = false,
    bool rules = false,
    bool migration = false,
  }) =>
      WaffraSyncEligibility(
        explicitUserConsent: consent,
        firebaseUid: uid,
        linkedVaultOwnerUid: owner,
        recoveryKeyAvailable: recovery,
        dammamDatabaseVerified: region,
        securityRulesVerified: rules,
        localMigrationVerified: migration,
      );

  test('Google login alone never activates sync', () {
    final user = gate(uid: 'google-uid', owner: 'google-uid');
    expect(user.maySync, isFalse);
    expect(user.disabledReason, WaffraSyncDisabledReason.noUserConsent);
  });

  test('one user cannot send another local vault', () {
    final user = gate(consent: true, uid: 'person-a', owner: 'person-b',
        recovery: true, region: true, rules: true, migration: true);
    expect(user.maySync, isFalse);
    expect(user.disabledReason, WaffraSyncDisabledReason.unlinkedLocalVault);
  });

  test('missing region, rules, backup key or migration block upload', () {
    final common = (bool region, bool rules, bool recovery, bool migration) =>
        gate(consent: true, uid: 'uid', owner: 'uid',
            region: region, rules: rules, recovery: recovery, migration: migration);
    expect(common(false, true, true, true).maySync, isFalse);
    expect(common(true, false, true, true).maySync, isFalse);
    expect(common(true, true, false, true).maySync, isFalse);
    expect(common(true, true, true, false).maySync, isFalse);
  });

  test('all checks must be explicitly satisfied', () {
    final ready = gate(consent: true, uid: 'uid', owner: 'uid',
        recovery: true, region: true, rules: true, migration: true);
    expect(ready.maySync, isTrue);
    expect(ready.disabledReason, isNull);
  });
}

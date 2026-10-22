import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_finance_source_cutover_policy.dart';

/// M83 read-only, synthetic release guard. Passing M79-M82 unit tests MUST
/// NOT be interpreted as proof that encrypted source cutover is safe to ship.
void main() {
  const source = WaffraFinanceSourceCutoverPolicy();
  const activation = WaffraFinanceSourceCutoverPolicy.preferenceActivationKey;
  const gate = WaffraCutoverReadinessGate();

  WaffraFinanceSourceStatus choose({
    bool file = false,
    bool key = false,
    bool sql = false,
    bool marker = false,
    bool feature = true,
  }) => source.resolve(WaffraFinanceSourceEvidence(
    preferences: marker ? const {activation: true} : const {},
    encryptedFileExists: file,
    encryptedKeyReadable: key,
    encryptedSqlActivationVerified: sql,
    encryptedFeatureAvailable: feature,
    cooperatingWritersFrozen: true,
  ));

  WaffraCutoverReadinessEvidence report({
    bool finance = true,
    bool receipts = true,
    bool home = true,
    bool widget = true,
    bool key = true,
    bool witnesses = true,
    bool android = true,
    bool backup = true,
  }) => WaffraCutoverReadinessEvidence(
    legacySnapshot: const {'entries': '[]'},
    encryptedFinanceMatches: finance,
    receiptBytesMatch: receipts,
    allFinanceWritersRouted: home,
    widgetWriterRouted: widget,
    encryptedKeyRecoverable: key,
    twoWitnessActivationRecoverable: witnesses,
    androidColdStartVerified: android,
    backupRestoreVerified: backup,
  );

  test('M83 all 32 encrypted activation witness combinations fail closed',
      () {
    var combinations = 0;
    for (final file in [false, true]) {
      for (final key in [false, true]) {
        for (final sql in [false, true]) {
          for (final marker in [false, true]) {
            for (final feature in [false, true]) {
              combinations++;
              final status = choose(
                file: file, key: key, sql: sql,
                marker: marker, feature: feature,
              );
              final complete = file && key && sql && marker && feature;
              if (complete) {
                expect(status, WaffraFinanceSourceStatus.encryptedVault);
              } else if (file || key || sql || marker) {
                expect(status, WaffraFinanceSourceStatus.recoveryRequired,
                    reason: 'incomplete independent activation witnesses');
              } else {
                expect(status, isNot(WaffraFinanceSourceStatus.encryptedVault));
              }
            }
          }
        }
      }
    }
    expect(combinations, 32);
  });

  test('M83 missing old encrypted file can never be treated as a new installation',
      () {
    expect(choose(marker: true, key: true, sql: true),
        WaffraFinanceSourceStatus.recoveryRequired);
    expect(choose(file: true, key: false, sql: true, marker: true),
        WaffraFinanceSourceStatus.recoveryRequired);
    expect(choose(file: true, key: true, sql: true, marker: true,
        feature: false), WaffraFinanceSourceStatus.recoveryRequired);
  });

  test('M83 each of eight release evidences independently blocks activation',
      () {
    final scenarios = <String, WaffraCutoverReadinessEvidence>{
      'encrypted_finance_parity_missing': report(finance: false),
      'encrypted_receipt_byte_parity_missing': report(receipts: false),
      'dashboard_sms_recurring_writers_not_routed': report(home: false),
      'widget_writer_not_routed': report(widget: false),
      'encrypted_key_recovery_not_verified': report(key: false),
      'two_witness_activation_recovery_missing': report(witnesses: false),
      'android_cold_start_not_verified': report(android: false),
      'backup_restore_not_verified': report(backup: false),
    };
    expect(scenarios, hasLength(8));
    for (final scenario in scenarios.entries) {
      final outcome = gate.inspect(scenario.value);
      expect(outcome.canActivate, isFalse);
      expect(outcome.blockers, contains(scenario.key));
      expect(outcome.blockers, hasLength(1),
          reason: 'identify the individual missing release evidence');
    }
  });

  test('M83 complete unit tests do not replace blocked real production routing',
      () {
    // These flags represent CURRENT outstanding work, even when synthetic
    // Android, Firestore, receipt and SMS tests independently pass.
    final state = gate.inspect(report(
      home: false,
      widget: false,
      key: false,
      witnesses: false,
      backup: false,
    ));
    expect(state.canActivate, isFalse);
    expect(state.blockers, containsAll([
      'dashboard_sms_recurring_writers_not_routed',
      'widget_writer_not_routed',
      'encrypted_key_recovery_not_verified',
      'two_witness_activation_recovery_missing',
      'backup_restore_not_verified',
    ]));
    expect(state.blockers, hasLength(5));
    // Do not flip markers or treat this guard as a migration.
  });
}

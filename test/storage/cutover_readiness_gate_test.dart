import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';

void main() {
  const gate = WaffraCutoverReadinessGate();

  WaffraCutoverReadinessEvidence evidence({
    Map<String, Object?> legacy = const {'entries': '[]'},
    bool finance = true,
    bool receipts = true,
    bool writers = true,
    bool widget = true,
    bool key = true,
    bool witnesses = true,
    bool android = true,
    bool backup = true,
  }) => WaffraCutoverReadinessEvidence(
    legacySnapshot: legacy,
    encryptedFinanceMatches: finance,
    receiptBytesMatch: receipts,
    allFinanceWritersRouted: writers,
    widgetWriterRouted: widget,
    encryptedKeyRecoverable: key,
    twoWitnessActivationRecoverable: witnesses,
    androidColdStartVerified: android,
    backupRestoreVerified: backup,
  );

  test('all independent evidence is required for eligibility', () {
    final result = gate.inspect(evidence());
    expect(result.canActivate, isTrue);
    expect(result.blockers, isEmpty);
    expect(result.sourceDigest, hasLength(64));
  });

  test('a successful finance copy alone never authorizes activation', () {
    final result = gate.inspect(evidence(
      receipts: false, writers: false, widget: false,
      key: false, witnesses: false, android: false, backup: false,
    ));
    expect(result.canActivate, isFalse);
    expect(result.blockers, hasLength(7));
  });

  test('receipt parity is mandatory even with matching finance digest', () {
    final result = gate.inspect(evidence(receipts: false));
    expect(result.blockers, contains('encrypted_receipt_byte_parity_missing'));
  });

  test('unrouted Android widget independently blocks cutover', () {
    final result = gate.inspect(evidence(widget: false));
    expect(result.blockers, contains('widget_writer_not_routed'));
  });

  test('corrupt legacy finance blocks activation even if all flags are true', () {
    final result = gate.inspect(evidence(legacy: {'entries': 'not json'}));
    expect(result.blockers, contains('legacy_finance_invalid'));
  });

  test('missing key recovery or cold start blocks activation', () {
    final result = gate.inspect(evidence(key: false, android: false));
    expect(result.canActivate, isFalse);
    expect(result.blockers, contains('encrypted_key_recovery_not_verified'));
    expect(result.blockers, contains('android_cold_start_not_verified'));
  });
}

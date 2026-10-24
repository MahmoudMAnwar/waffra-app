import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M112: encrypted route requires independent device and external witnesses', () {
    final authority = File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    for (final witness in [
      'encryptedSqlWitnessActive',
      'externalSourceWitnessActive',
      'verifiedKeyRecoveryInDevice',
    ]) {
      expect(authority, contains(witness), reason: witness);
    }
    expect(authority, contains('Verified encrypted finance runtime is missing.'));
  });

  test('M112: source witness must be checked before writing Home state', () {
    final authority = File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    final begin = authority.indexOf('Future<WaffraFinanceAuthorityRead> saveCaptured(');
    final end = authority.indexOf('Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms(', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(end, greaterThan(begin));
    final save = authority.substring(begin, end);
    expect(save.indexOf('backend != baseline.source'), lessThan(save.indexOf('legacy.saveLegacy(')));
    expect(save, contains('expectedWidgetRevision: baseline.widgetRevision'));
    expect(save, contains('expectedLedgerRaw: baseline.ledgerRaw'));
  });

  test('M112: no implicit migration or cloud activation in authority', () {
    final authority = File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    expect(authority, isNot(contains('FirebaseFirestore.instance')));
    expect(authority, isNot(contains('deleteDatabase(')));
    expect(authority, isNot(contains('runMigration(')));
  });
}

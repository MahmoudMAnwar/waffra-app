import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M110 Home finance persists through source authority, never direct legacy', () {
    final main = File('lib/main.dart').readAsStringSync();
    final authority = File('lib/storage/waffra_verified_finance_authority.dart')
      .readAsStringSync();
    expect(main, contains('_financeAuthority.saveCaptured('));
    expect(main, contains('WaffraFinanceRoute.transactionEdit'));
    expect(main, contains('WaffraFinanceRoute.deleteAllTransactions'));
    expect(main, contains('WaffraFinanceRoute.fullFinanceReset'));
    expect(main, contains('_financeAuthority.commitConfirmedSms('));
    expect(main, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
    expect(main, isNot(contains('_homeFinancePersistence.saveLegacy(')));
    expect(main, isNot(contains('_homeFinancePersistence.commitConfirmedLegacySms(')));
    expect(authority, contains('legacy.saveLegacy('));
    expect(authority, contains('legacy.commitConfirmedLegacySms('));
    expect(authority, contains('encryptedSession!.appendConfirmed('));
  });

  test('M110 source witness captured before queued write; widget cannot be overwritten', () {
    final main = File('lib/main.dart').readAsStringSync();
    // M175 intentionally makes the route an argument: a stale widget must
    // still never overwrite the baseline, regardless of mutation intent.
    final start = main.indexOf(' Future<void> persist({');
    expect(start, greaterThan(0),
        reason: 'All Home mutations must share one source-aware persist entry');
    final end = main.indexOf(' Future<void> _persistSmsHashes', start);
    expect(end, greaterThan(start), reason: 'Persist boundary must be intact');
    final persist = main.substring(start, end);
    expect(persist, contains(
      'WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit'));
    expect(persist, contains('route:route,'));
    final witness = persist.indexOf('final baseline=_lastFinanceAuthorityRead;');
    final submit = persist.indexOf('_financialWriteQueue.submit(');
    expect(witness, greaterThan(0));
    expect(submit, greaterThan(witness));
    expect(persist, contains('baseline:baseline'));
    expect(persist, contains('_lastFinanceAuthorityRead=committed'));
    expect(main, contains('_lastFinanceAuthorityRead=loadedFinance;'));
  });

  test('M110 encrypted snapshot-only edits fail closed pending typed SQL projection', () {
    final authority = File('lib/storage/waffra_verified_finance_authority.dart')
      .readAsStringSync();
    final start = authority.indexOf('Future<WaffraFinanceAuthorityRead> saveCaptured(');
    final end = authority.indexOf('Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms(', start);
    final code = authority.substring(start, end);
    expect(code, contains('Encrypted screen mutation requires a verified atomic SQL projection writer.'));
    expect(code, isNot(contains('encryptedSession!.saveDashboardBatch(')));
    expect(code, contains('_requireRoute(route)'));
  });

  test('M110 financial deletion carries baseline, not a fresh post-widget snapshot', () {
    final main = File('lib/main.dart').readAsStringSync();
    for (final route in ['deleteAllTransactions','fullFinanceReset']) {
      final start = main.indexOf('route:WaffraFinanceRoute.$route');
      expect(start, greaterThan(0), reason: route);
      final before = main.substring(start > 440 ? start - 440 : 0, start);
      expect(before, contains('final baseline=_lastFinanceAuthorityRead;'),
          reason: route);
    }
  });
}

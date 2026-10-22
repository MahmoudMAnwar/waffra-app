import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final authority = File('lib/storage/waffra_verified_finance_authority.dart')
      .readAsStringSync();

  test('M111: stale Home source witness fails closed before persistence', () {
    final start = authority.indexOf('Future<WaffraFinanceAuthorityRead> saveCaptured(');
    final end = authority.indexOf('Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = authority.substring(start, end);
    expect(method, contains('backend != baseline.source'));
    expect(method, contains('Finance authority changed while screen was open.'));
    expect(method.indexOf('backend != baseline.source'),
        lessThan(method.indexOf('legacy.saveLegacy(')));
  });

  test('M111: encrypted screen edits cannot silently write snapshot only', () {
    expect(authority, contains(
        'Encrypted screen mutation requires a verified atomic SQL projection writer.'));
    expect(authority, isNot(contains('encryptedSession!.saveDashboardBatch(')));
  });

  test('M111: unconfirmed, oversized or malformed SMS batches fail before routing', () {
    final start = authority.indexOf('Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms(');
    expect(start, greaterThanOrEqualTo(0));
    final method = authority.substring(start);
    expect(method, contains('!userConfirmed'));
    expect(method, contains('records.isEmpty'));
    expect(method, contains('records.length > 100'));
    expect(method, contains('hashes.length != records.length'));
    expect(method.indexOf('!userConfirmed'),
        lessThan(method.indexOf('await _requireRoute(route)')));
  });

  test('M111: no optimistic successful Home save before durable reload', () {
    final start = authority.indexOf('Future<WaffraFinanceAuthorityRead> saveCaptured(');
    final end = authority.indexOf('Future<WaffraFinanceAuthoritySmsCommit> commitConfirmedSms(', start);
    final method = authority.substring(start, end);
    expect(method, contains('return load(route: route);'));
    expect(method.indexOf('await legacy.saveLegacy('),
        lessThan(method.indexOf('return load(route: route);')));
  });
}

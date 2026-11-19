import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M1040/#769: protect the fee-bearing SMS route as well as manual transfers.
/// Core money tests run against disposable SQLCipher in test/storage/m1040_....
void main() {
  test('M1040 fee writer passes full fee into the atomic source cash gate', () {
    final all = File('lib/storage/waffra_unified_finance_writer.dart')
        .readAsStringSync();
    final start = all.indexOf('Future<bool> appendReviewedSmsTransferWithFee({');
    final end = all.indexOf('/// Called AFTER explicit confirmation for bank SMS', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final feeWriter = all.substring(start, end);
    expect(feeWriter, contains(
      'feeIncludedInDebit ? principalMinor - feeMinor : principalMinor'));
    // The transfer is *credited* money, but the source also pays one fee.
    // Guard the sum under the same transaction, before inserting ANY money.
    expect(feeWriter, contains('additionalSourceDebitMinor: feeMinor'));
    expect(feeWriter, contains('amountMinor: creditedMinor'));
    expect(feeWriter.indexOf('additionalSourceDebitMinor: feeMinor'),
      lessThan(feeWriter.indexOf("'INSERT INTO fresh_finance_entries '")));
    expect(feeWriter, contains("'INSERT INTO fresh_finance_sms_hashes (message_hash) VALUES (?)'"));
    expect(feeWriter, contains('snapshot.store.transaction(() async {'));
    expect(feeWriter, contains('if (hashes.contains(messageHash)) {'));
    expect(feeWriter, contains('return false;'));
  });

  test('M1040 account transfer source guard cannot read a stale UI balance', () {
    final repo = File('lib/storage/waffra_accounts_repository.dart')
        .readAsStringSync();
    final start = repo.lastIndexOf('Future<bool> transfer({required String id');
    final end = repo.indexOf('/// M1032: reverse an incorrect internal transfer', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final writer = repo.substring(start, end);
    expect(writer, contains('return db.transaction(()async{'));
    expect(writer, contains('final currentBalances=await balances();'));
    expect(writer, contains('source.balanceMinor < requiredSourceDebitMinor'));
    expect(writer.indexOf('final currentBalances=await balances();'),
      lessThan(writer.indexOf("'INSERT INTO fresh_finance_internal_transfers '"),
       reason: 'Available balance must be re-read before the insert.'));
    expect(writer, contains('return false;'),
      reason: 'Exact replay must be idempotent after the first debit.');
    final reversal = repo.substring(end);
    expect(reversal, contains('Future<bool> reverseInternalTransfer('));
    expect(reversal, contains("'INSERT INTO fresh_finance_internal_transfers '"));
  });
}

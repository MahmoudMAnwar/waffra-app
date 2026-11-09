import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_transaction_form.dart';

void main() {
 test('M611 transfer SAR parser accepts only legitimate grouped amounts', () {
  expect(waffraSarAmountMinor('1,000'), 100000);
  expect(waffraSarAmountMinor('1,000.50'), 100050);
  expect(waffraSarAmountMinor('١٬٠٠٠٫٥٠'), 100050);
  expect(waffraSarAmountMinor('1000.50'), 100050);
  expect(waffraSarAmountMinor('1,00'), isNull);
  expect(waffraSarAmountMinor('10,00'), isNull);
  expect(waffraSarAmountMinor('1,000.123'), isNull);
  expect(waffraSarAmountMinor('-1,000'), isNull);
  expect(waffraSarAmountMinor('0'), isNull);
 });

 test('M611 Home action tiles show read-only histories, never an add form', () {
  final src = File('lib/main.dart').readAsStringSync();
  final start=src.indexOf("Row(key:const Key('m549-three-home-finance-actions')");
  final end=src.indexOf('          const SizedBox(height:10),',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final home=src.substring(start,end);
  expect(home,contains('showSummaryTransactions(true)'));
  expect(home,contains('showSummaryTransactions(false)'));
  expect(home,contains('showInternalTransferTransactions()'));
  expect(home,isNot(contains('entrySheet(')));
  expect(home,isNot(contains('openVerifiedTransfer()')));
  final tile=src.substring(src.indexOf('Widget _m549HomeFinanceAction({'),
   src.indexOf('Widget dashboard(){'));
  expect(tile,contains('height:68,'));
 });

 test('M611 account selection is readable and mandatory for manual save', () {
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Widget monthlySummaryCard()');
  final end=src.indexOf('Future<void> showSummaryTransactions(',start);
  final summary=src.substring(start,end);
  expect(summary,contains("key:const Key('m549-home-account-filter')"));
  expect(summary,contains("label:Text(_m467AccountLabel,softWrap:true"));
  expect(summary,isNot(contains('BoxConstraints(maxWidth:100)')));
  final editor=src.substring(src.indexOf('Future<void> entrySheet('),
   src.indexOf('Future<void> showReceipt('));
  expect(editor,contains('errorText:attempted&&initial==null&&!sms&&chosenManualAccount==null'));
  expect(editor,contains('p.id==chosenManualProvider&&'));
  expect(editor,contains('p.accounts.any((a)=>a.id==chosenManualAccount)'));
 });

 test('M611 transfer history reads real encrypted rows under owner witness', () {
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Future<void> showInternalTransferTransactions()async');
  final end=src.indexOf('Widget _dashboardShortcut(',start);
  final tile=src.substring(start,end);
  expect(tile,contains('readInternalTransferHistory('));
  expect(tile,contains("accountId:selected=='all'?null:selected"));
  expect(tile,isNot(contains('transferApi!.transfer(')));
  final context=File('lib/storage/waffra_account_context_repository.dart').readAsStringSync();
  expect(context,contains('FROM fresh_finance_internal_transfers'));
  expect(context,contains('WHERE from_account_id=? OR to_account_id=?'));
  final api=File('lib/storage/waffra_verified_accounts_api.dart').readAsStringSync();
  expect(api,contains('bridge.readVerifiedAccountMetadata((context)=>'));
  expect(api,contains('context.readInternalTransferHistory('));
 });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M810 original income/expense summary dialog is registered and read only',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_transaction_summary.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_transaction_summary.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeTransactionSummary on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> showSummaryTransactions(bool income)async {')));
  expect(part,contains(' Future<void> showSummaryTransactions(bool income)async {'));
  expect(part,contains('_m467ScopedEntries()'));
  expect(part,contains('sum(items,income)'));
  expect(part,contains('showModalBottomSheet<void>('));
  expect(part,contains('WaffraText(cash(e.amount)'));
  expect(part,contains('No transactions yet'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('commitConfirmedSms(')));
 });
 test('M810 original summary body is available without altered finance values',(){
  final actual=readWaffraMainSourceForContracts();
  final start=actual.indexOf(' Future<void> showSummaryTransactions(bool income)async {');
  final end=actual.indexOf(' Future<void> showInternalTransferTransactions()async{',start);
  final part=File('lib/waffra_home_transaction_summary.part.dart').readAsStringSync();
  final source=part.substring(part.indexOf(' Future<void> showSummaryTransactions(bool income)async {'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(actual.substring(start,end),source);
 });
}

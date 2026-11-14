import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M790 original financial activity cards are registered and never post funds',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_compact_activity_cards.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_compact_activity_cards.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeCompactActivityCards on _HomeScreenState'));
  expect(main,isNot(contains(' Widget compactTransaction(MoneyEntry entry){')));
  expect(part,contains(' Widget compactTransaction(MoneyEntry entry){'));
  expect(part,contains(' Widget _m549HomeFinanceAction('));
  expect(part,contains("entry.sourceType=='recurring'||entry.sourceType=='goal_due'"));
  expect(part,contains('WaffraTransactionDetailsDialog.sourceLabel('));
  expect(part,contains('WaffraReceiptCornerAction('));
  expect(part,contains('waffraReceiptPaths(entry.receiptPath)'));
  expect(part,contains('this._m684HomeFinanceAction('));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
 });
 test('M790 old activity card source checks see unchanged registered body',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' Widget compactTransaction(MoneyEntry entry){');
  final end=full.indexOf(' Widget categoriesPage()=>',start);
  final part=File('lib/waffra_home_compact_activity_cards.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Widget compactTransaction(MoneyEntry entry){'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}

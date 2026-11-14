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
  var original=part.substring(part.indexOf(' Widget compactTransaction(MoneyEntry entry){'),
   part.lastIndexOf('\n}')+1);
  String registeredMethod(String path,String signature){
   final code=File(path).readAsStringSync();
   final at=code.indexOf(signature),endOfPart=code.lastIndexOf('\n}');
   expect(at,greaterThanOrEqualTo(0),reason:path);
   expect(endOfPart,greaterThan(at),reason:path);
   return code.substring(at,endOfPart+1);
  }
  const dashboardMarker=' // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.\n';
  const categoryMarker=' // M735: Home category workflows extracted unchanged to registered same-library part.\n';
  expect(original.split(dashboardMarker).length,2);
  expect(original.split(categoryMarker).length,2);
  original=original.replaceFirst(dashboardMarker,
   registeredMethod('lib/waffra_home_dashboard_analytics.part.dart',' Widget dashboard(){'));
  original=original.replaceFirst(categoryMarker,
   registeredMethod('lib/waffra_home_category_workflows.part.dart',' Future<BudgetCategory?> categoryDialog('));
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}

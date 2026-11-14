import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M805 real registered budget alert and chart functions preserve financial source',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_budget_alert_charts.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_budget_alert_charts.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeBudgetAlertCharts on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _requestPercentageAlertPermission()async{')));
  for(final symbol in <String>[
   ' Future<void> _requestPercentageAlertPermission()async{',
   ' Future<void> budgetAlert(',
   ' String expensePieSvg(',
   ' String weeklySpendSvg(',
   ' String pairedBarChartSvg(',
   'WaffraReminders.requestPermission()',
  ]) {
   expect(part,contains(symbol),reason:symbol);
  }
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
 });
 test('M805 original code-based regressions use identical chart/alert production part',(){
  final whole=readWaffraMainSourceForContracts();
  final start=whole.indexOf(' Future<void> _requestPercentageAlertPermission()async{');
  final end=whole.indexOf(' Future<void> confirmDeleteAllEntries() async {',start);
  final part=File('lib/waffra_home_budget_alert_charts.part.dart').readAsStringSync();
  final source=part.substring(part.indexOf(' Future<void> _requestPercentageAlertPermission()async{'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(whole.substring(start,end),source);
 });
}

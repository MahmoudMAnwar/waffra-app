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
  var source=part.substring(part.indexOf(' Future<void> _requestPercentageAlertPermission()async{'),
   part.lastIndexOf('\n}')+1);
  String registeredMethod(String path,String signature){
   final code=File(path).readAsStringSync();
   final at=code.indexOf(signature),endOfPart=code.lastIndexOf('\n}');
   expect(at,greaterThanOrEqualTo(0),reason:path);
   expect(endOfPart,greaterThan(at),reason:path);
   return code.substring(at,endOfPart+1);
  }
  const ledgerMarker=' // M780: original verified ledger deletion/undo and source publication moved to registered Home part.\n';
  const cardsMarker=' // M781: original Home transaction cards/details/actions moved to registered same-library part.\n';
  expect(source.split(ledgerMarker).length,2);
  expect(source.split(cardsMarker).length,2);
  source=source.replaceFirst(ledgerMarker,
   registeredMethod('lib/waffra_home_transaction_ledger_actions.part.dart',' void _publishVerifiedTransactionLedger('));
  source=source.replaceFirst(cardsMarker,
   registeredMethod('lib/waffra_home_transaction_cards.part.dart',' Widget stat(String label'));
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(whole.substring(start,end),source);
 });
}

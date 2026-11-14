import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M820 original M805 chart source exposes nested real M780 ledger and M781 card methods',(){
  final main=File('lib/main.dart').readAsStringSync();
  final chart=File('lib/waffra_home_budget_alert_charts.part.dart').readAsStringSync();
  const a=' // M805: original Home budget alerts and chart SVG methods moved to registered part.';
  const b=' // M780: original verified ledger deletion/undo and source publication moved to registered Home part.';
  const c=' // M781: original Home transaction cards/details/actions moved to registered same-library part.';
  expect(main,contains(a));
  expect(main,isNot(contains(b)));
  expect(main,isNot(contains(c)));
  expect(chart,startsWith("part of 'main.dart';"));
  expect(chart,contains(b));
  expect(chart,contains(c));
  final actual=readWaffraMainSourceForContracts();
  final chartAt=actual.indexOf(' Future<void> _requestPercentageAlertPermission()async{');
  final ledgerAt=actual.indexOf(' void _publishVerifiedTransactionLedger(');
  final cardsAt=actual.indexOf(' Widget stat(String label');
  expect(chartAt,greaterThan(0));
  expect(ledgerAt,greaterThan(chartAt));
  expect(cardsAt,greaterThan(ledgerAt));
  expect(actual,isNot(contains(a)));
  expect(actual,isNot(contains(b)));
  expect(actual,isNot(contains(c)));
 });
}

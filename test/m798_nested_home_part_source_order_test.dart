import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M798 real compact-card Dart part precedes nested dashboard/category parts',(){
  final main=File('lib/main.dart').readAsStringSync();
  final compact=File('lib/waffra_home_compact_activity_cards.part.dart').readAsStringSync();
  const compactMarker=' // M790: original compact financial activity cards live in registered Home part.';
  const dashboardMarker=' // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.';
  const categoryMarker=' // M735: Home category workflows extracted unchanged to registered same-library part.';
  expect(main,contains(compactMarker));
  expect(main,isNot(contains(dashboardMarker)));
  expect(main,isNot(contains(categoryMarker)));
  expect(compact,startsWith("part of 'main.dart';"));
  expect(compact,contains(dashboardMarker));
  expect(compact,contains(categoryMarker));
  final real=readWaffraMainSourceForContracts();
  expect(real,contains(' Widget compactTransaction(MoneyEntry entry){'));
  expect(real,contains(' Widget dashboard(){'));
  expect(real,contains(' Future<BudgetCategory?> categoryDialog('));
  expect(real,isNot(contains(compactMarker)));
  expect(real,isNot(contains(dashboardMarker)));
  expect(real,isNot(contains(categoryMarker)));
 });
}

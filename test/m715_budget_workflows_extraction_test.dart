import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M715 production budget workflows are registered once',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_budget_workflows.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_budget_workflows.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeBudgetWorkflows on _HomeScreenState'));
  expect(part,contains('Future<void> editMonthlyBudget()'));
  expect(part,contains('Future<void> editBudgetForCategory('));
  expect(part,contains('Future<void> assignExistingExpenseToBudget('));
  expect(part,contains('Future<void> reviewUnlinkedHistoricalExpenses()'));
  expect(main,isNot(contains(' Future<void> editMonthlyBudget()async {')));
 });
 test('M715 original budgets appear in exact restored source order',(){
  final text=readWaffraMainSourceForContracts();
  final start=text.indexOf(' Future<void> editMonthlyBudget(');
  final end=text.indexOf(' Future<void> showSummaryTransactions(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final content=text.substring(start,end);
  expect(content,contains('reviewUnlinkedHistoricalExpenses'));
  expect(content,contains('setNamedBudgetActive'));
  expect(content,contains('editBudgetForCategory'));
  expect(content,contains('refreshFromBudgetDirectory'));
 });
}

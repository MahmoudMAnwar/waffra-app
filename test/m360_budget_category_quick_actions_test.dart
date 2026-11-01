import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M360 main category quick actions are collapsed by default',(){
  final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(categories,contains("'waffra-root-category-actions-'"));
  expect(categories,contains('initiallyExpanded:false'));
  expect(categories,contains('addCategory(income:root.income,parentId:root.id)'));
  expect(categories,contains('updateCategory(root)'));
  expect(categories,contains('deleteCategory(root)'));
 });

 test('M360 subcategory actions are collapsed and allow edit/delete',(){
  final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(categories,contains("'waffra-subcategory-actions-'"));
  expect(categories,contains('updateCategory(sub)'));
  expect(categories,contains('deleteCategory(sub)'));
 });

 test('M360 saved budget actions are in My Budgets only',(){
  final budgets=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
  final app=File('lib/main.dart').readAsStringSync();
  expect(budgets,contains("'waffra-budget-quick-actions-'"));
  expect(budgets,contains('editBudgetForCategory(b)'));
  expect(budgets,contains('setNamedBudgetActive(b,!b.budgetActive)'));
  expect(budgets,contains('deleteNamedBudget(b)'));
  expect(app,isNot(contains("'waffra-named-budget-enabled-switch'")));
  expect(app,isNot(contains("'waffra-delete-selected-named-budget'")));
  expect(app,contains("'waffra-month-budget-expand-toggle'"));
 });

 test('M360 bank SMS batch review also permits creating a new budget',(){
  final app=File('lib/main.dart').readAsStringSync();
  expect(app,contains("'waffra-entry-create-named-budget'"));
  expect(app,contains("'waffra-sms-batch-create-budget-'"));
  expect(app,contains('assigned[n]=id;'));
  expect(app,contains('choices\n              ..clear()'));
 });

 test('M360 overall budget and allowance are projections of saved budgets',(){
  final app=File('lib/main.dart').readAsStringSync();
  expect(app,contains('final overallLimit=allBudgets.fold<double>'));
  expect(app,contains('final overallSpent=monthEntries.where('));
  expect(app,contains('final activeCap=activeBudgets.fold<double>'));
  expect(app,contains('monthlyBudget:activeCap,spent:activeBudgetSpent'));
  expect(app,contains('budgetId!=null&&activeIds.contains(e.budgetId)'));
 });
}

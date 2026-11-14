import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M735 Home category and trash actions are actual registered Dart part',() {
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_category_workflows.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_category_workflows.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeCategoryWorkflows on _HomeScreenState'));
  expect(main,isNot(contains(' Future<BudgetCategory?> categoryDialog(')));
  for(final anchor in <String>[
   ' Future<BudgetCategory?> categoryDialog(',
   ' Future<void> chooseCategoryLevel(',
   ' Future<void> setCategoryActive(',
   ' Future<void> addCategory(',
   ' Future<void> updateCategory(',
   ' Future<void> _deleteVerifiedModule(',
   ' Future<void> _restoreVerifiedModule(',
   ' Future<void> _showVerifiedModuleTrash(',
   ' Future<void> deleteCategory(',
   ' Future<void> showCategoryTrash(',
  ]) {
   expect(part,contains(anchor),reason:anchor);
  }
 });
 test('M735 finance and category safety source exactly reconstructs production',() {
  final main=readWaffraMainSourceForContracts();
  final start=main.indexOf(' Future<BudgetCategory?> categoryDialog(');
  final end=main.indexOf(' Widget categoriesPage()=>',start);
  final file=File('lib/waffra_home_category_workflows.part.dart').readAsStringSync();
  final real=file.substring(file.indexOf(' Future<BudgetCategory?> categoryDialog('),
   file.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(main.substring(start,end),real);
 });
}

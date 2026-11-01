import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M348 category sorting is display-only and keeps finance IDs intact',(){
  final page=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains("String categorySort='default'"));
  expect(home,contains('bool categoryFiltersOpen=false'));
  expect(page,contains('waffraRankCategoryRoots<BudgetCategory>(shown'));
  expect(page,contains('mode:categorySort'));
  expect(page,contains("categorySort='default'"));
  expect(page,contains('categorySort=v'));
  expect(page,contains("value:'income'"));
  expect(page,contains("value:'spent'"));
  expect(page,contains("value:'alpha'"));
  expect(page,isNot(contains("persist(route:WaffraFinanceRoute")));
  expect(page,isNot(contains('entries.sort(')));
  expect(page,isNot(contains('categories.sort(')));
 });
}

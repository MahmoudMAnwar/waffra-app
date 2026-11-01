import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M348 display sorting does not modify finance storage or entity IDs',(){
  final page=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains("String categorySort='default'"));
  expect(page,contains("categorySort=='alpha'"));
  expect(page,contains("categorySort=='spent'"));
  expect(page,contains('final spentById={for(final root in shown)'));
  expect(page,contains("categorySort='default'"));
  expect(page,contains("categorySort='spent'"));
  expect(page,contains("categorySort='alpha'"));
  expect(page,isNot(contains("persist(route:WaffraFinanceRoute")));
  expect(page,isNot(contains('entries.sort(')));
  expect(page,isNot(contains('categories.sort(')));
 });
}

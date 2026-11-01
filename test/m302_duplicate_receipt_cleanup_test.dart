import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M302 refuse duplicate means no new finance write and staged receipt removed',(){
  final main=File('lib/main.dart').readAsStringSync();
  final entry=main.indexOf('Future<void> entrySheet(');
  final duplicate=main.indexOf('if(initial==null&&entries.any((e)=>',entry);
  // M344 changed the expense projection from an unlinked sum to an
  // explicitly linked named-budget total. The duplicate rejection must
  // still finish (including staged receipt cleanup) before that projection.
  final budgetProjection=main.indexOf('final linkedBudget=categories.where(',duplicate);
  final commit=main.indexOf(
    'final previousSpent=linkedBudget.isEmpty?0.0:waffraNamedBudgetSpent(',
    budgetProjection);
  expect(entry,greaterThan(0));
  expect(duplicate,greaterThan(entry));
  expect(budgetProjection,greaterThan(duplicate));
  expect(commit,greaterThan(budgetProjection));
  final review=main.substring(duplicate,budgetProjection);
  expect(review,contains('if(proceed!=true||!mounted){'));
  expect(review,contains('for(final copy in stagedReceiptCopies)'));
  expect(review,contains('if(await file.exists())await file.delete()'));
  expect(review,contains('return;'));
  expect(main,contains('if(result==null||!mounted)'));
  expect(main,contains('await persist(route:initial==null'));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M302 all optimistic module writes must recover authoritative finance state',(){
  final s=File('lib/main.dart').readAsStringSync();
  final guardStart=s.indexOf('Future<bool> _persistModuleOrReload(');
  final guardEnd=s.indexOf('Future<void> _persistSmsHashes(',guardStart);
  expect(guardStart,greaterThan(0));
  expect(guardEnd,greaterThan(guardStart));
  final guard=s.substring(guardStart,guardEnd);
  expect(guard,contains('await persist(route:route);'));
  expect(guard,contains('if(mounted)await _loadFinanceSafely();'));
  expect(guard,contains('return false;'));
  expect(guard,contains('return true;'));
 });

 test('M302 goal funding does not celebrate uncommitted savings',(){
  final code=File('lib/main.dart').readAsStringSync();
  final start=code.indexOf('Future<void> fundGoal(');
  final end=code.indexOf('IconData goalIcon(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final source=code.substring(start,end);
  final guarded=source.indexOf("operation:'goal-funding'");
  final congratulations=source.indexOf('if(achieved&&mounted)');
  expect(guarded,greaterThan(0));
  expect(congratulations,greaterThan(guarded));
  expect(source,contains("if(!await _persistModuleOrReload("));
 });

 test('M302 category picker never selects a name when create is rejected',(){
  final code=File('lib/main.dart').readAsStringSync();
  final start=code.indexOf('if(sms&&suggestion!=null)TextButton.icon(');
  final end=code.indexOf('const SizedBox(height:12),',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final picker=code.substring(start,end);
  for(final mutation in <String>[
    "operation:'bank-category-suggestion'",
    "operation:'bank-new-category'",
    "operation:'manual-new-subcategory'",
  ]){
   expect(picker,contains(mutation),reason:mutation);
  }
  final allGuards='if(!await _persistModuleOrReload('
      .allMatches(picker).length;
  expect(allGuards,3);
  expect(picker,contains("if(sheetContext.mounted)update(()=>category=c.name)"));
 });

 test('M302 recurring reminders are not scheduled for rejected mutations',(){
  final code=File('lib/main.dart').readAsStringSync();
  final mainStart=code.indexOf('Widget recurringPage()');
  final end=code.indexOf('Future<void>',mainStart);
  expect(mainStart,greaterThan(0));
  // The recurring view is a long widget tree; check the exact tap handlers.
  final view=code.substring(mainStart,end<0?code.length:end);
  expect(view,contains("operation:'recurring-active-toggle'"));
  expect(view,contains("operation:'recurring-delete'"));
  expect(view,contains('if(enabled)await applyRecurring();'));
  expect(view,contains('await syncRecurringReminders();'));
  final toggleGuard=view.indexOf("operation:'recurring-active-toggle'");
  final toggleSync=view.indexOf('if(enabled)await applyRecurring();');
  expect(toggleSync,greaterThan(toggleGuard));
 });
}

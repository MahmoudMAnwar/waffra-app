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

 test('M302 inline category picker returns a new name only after durable save',(){
  final code=File('lib/main.dart').readAsStringSync();
  final start=code.indexOf('Future<String?> chooseTransactionCategory(');
  final end=code.indexOf('Future<String?> _promptReceiptLabel(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final picker=code.substring(start,end);
  expect(picker,contains('if(picked==null||!mounted||!ctx.mounted)return null;'));
  expect(picker,contains('if(picked!=createMain&&picked!=createSub)return picked;'));
  expect(picker,contains('income:typeIncome,parentId:categoryParentId,'));
  expect(picker,contains('WaffraValidators.uniqueCategory(created.name,'));
  expect(picker,contains('if(created==null||!mounted||!ctx.mounted)return null;'));
  final add=picker.indexOf('setState(()=>categories.add(created));');
  final persist=picker.indexOf('if(!await _persistModuleOrReload(',add);
  final operation=picker.indexOf("operation:'transaction-category-picker-create'",persist);
  final refuse=picker.indexOf('))return null;',operation);
  final selected=picker.indexOf('return created.name;',refuse);
  expect(add,greaterThan(0));
  expect(persist,greaterThan(add));
  expect(operation,greaterThan(persist));
  expect(refuse,greaterThan(operation));
  expect(selected,greaterThan(refuse),
    reason:'Never select an unsaved main/subcategory after a failed durable write');
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

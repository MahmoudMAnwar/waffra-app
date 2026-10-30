import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_recurring_policy.dart';

void main(){
 test('M302 future first due cannot appear in current-month overview',(){
  final today=DateTime(2026,10,30);
  expect(WaffraRecurringPolicy.nextDueDate(
   today:today,startAt:DateTime(2026,12,1),day:15),DateTime(2026,12,15));
  expect(WaffraRecurringPolicy.nextDueDate(
   today:today,startAt:DateTime(2026,12,20),day:15),DateTime(2027,1,15));
 });

 test('M302 monthly schedule clamps 31 and leap February safely',(){
  expect(WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2027,2,27),startAt:DateTime(2026,1,1),day:31),
   DateTime(2027,2,28));
  expect(WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2028,2,29),startAt:DateTime(2026,1,1),day:31),
   DateTime(2028,2,29));
  expect(WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2026,12,31),startAt:DateTime(2026,12,31),day:1),
   DateTime(2027,1,1));
 });

 test('M302 due today remains due; same-day future start respected',(){
  expect(WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2026,10,30),startAt:DateTime(2026,1,1),day:30),
   DateTime(2026,10,30));
  expect(WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2026,10,30),startAt:DateTime(2026,10,30,23,59),day:30),
   DateTime(2026,10,30));
 });

 test('M302 invalid schedule day fails closed',(){
  expect(()=>WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2026),startAt:DateTime(2026),day:0),throwsArgumentError);
  expect(()=>WaffraRecurringPolicy.nextDueDate(
   today:DateTime(2026),startAt:DateTime(2026),day:32),throwsArgumentError);
 });

 test('M302 unpaid past due remains visible, not silently moved to next month',(){
  final today=DateTime(2026,10,30);
  final due=WaffraRecurringPolicy.nextActionableDue(
   today:today,startAt:DateTime(2026,1,1),day:10,
   currentMonthPaid:false);
  expect(due,DateTime(2026,10,10));
  expect(due.isBefore(today),isTrue);
 });

 test('M302 paid due displays next occurrence and future starts stay future',(){
  expect(WaffraRecurringPolicy.nextActionableDue(
   today:DateTime(2026,10,30),startAt:DateTime(2026,1,1),day:10,
   currentMonthPaid:true),DateTime(2026,11,10));
  expect(WaffraRecurringPolicy.nextActionableDue(
   today:DateTime(2026,10,30),startAt:DateTime(2026,12,19),day:10,
   currentMonthPaid:false),DateTime(2027,1,10));
 });

 test('M302 postponement date appears without mutating this month ledger ID',(){
  final due=WaffraRecurringPolicy.dueDate(2026,10,10);
  final id=WaffraRecurringPolicy.entryId('rent',due);
  expect(WaffraRecurringPolicy.nextActionableDue(
   today:DateTime(2026,10,30),startAt:DateTime(2026,1,1),day:10,
   currentMonthPaid:false,postponedUntil:DateTime(2026,11,3)),
   DateTime(2026,11,3));
  expect(WaffraRecurringPolicy.entryId('rent',due),id);
 });

 test('M302 real app overview reads the same verified recurring due policy',(){
  final code=File('lib/main.dart').readAsStringSync();
  expect(code,contains('WaffraRecurringPolicy.nextActionableDue('));
  expect(code,contains('currentMonthPaid:entries.any((entry)=>entry.id==monthId)'));
  expect(code,contains("postponedUntil:DateTime.tryParse(recurringPostponed[monthId]??'')"));
 });
}

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

 test('M302 real app overview reads the same verified recurring due policy',(){
  final code=File('lib/main.dart').readAsStringSync();
  expect(code,contains('WaffraRecurringPolicy.nextDueDate('));
  expect(code,contains('today:DateTime.now(),startAt:r.startAt,day:r.day'));
 });
}

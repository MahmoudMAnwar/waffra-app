import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_financial_insights.dart';
import 'package:waffra/waffra_reminders.dart';

void main(){
 test('M444 canceling recurring reminders does not own bank notifications',(){
  expect(WaffraReminders.isManagedRecurringRequest(
   payload:'bank_sms_review:1',title:'Bank transaction'),isFalse);
  expect(WaffraReminders.isManagedRecurringRequest(
   payload:'waffra_recurring_due_v1:bill'),isTrue);
  expect(WaffraReminders.isManagedRecurringRequest(
   title:'وفرة • تذكير بالتزام قادم'),isTrue);
 });
 test('M444 goal-linked due reminders occur once',(){
  final goal=WaffraReminder(id:'g',title:'Goal',day:16,
   startAt:DateTime(2026,11,16),oneTimeDueAt:DateTime(2026,11,16));
  expect(WaffraReminders.upcomingDueDates(goal,DateTime(2026,11,4)),
   [DateTime(2026,11,16)]);
  expect(WaffraReminders.upcomingDueDates(goal,DateTime(2026,12,4)),isEmpty);
 });
 test('M444 monthly reminder respects future first occurrence',(){
  final recurring=WaffraReminder(id:'r',title:'Rent',day:12,
   startAt:DateTime(2026,12,1));
  final dates=WaffraReminders.upcomingDueDates(recurring,DateTime(2026,11,4));
  expect(dates.first,DateTime(2026,12,12));
  expect(dates.length,3);
 });
 test('M444 forecast does not debit next-month goal or schedule',(){
  expect(WaffraFinancialInsights.pendingCurrentMonth(
   now:DateTime(2026,11,4),startAt:DateTime(2026,12,16),
   day:16,goalLinked:true,alreadyPaid:false),isFalse);
  expect(WaffraFinancialInsights.pendingCurrentMonth(
   now:DateTime(2026,11,4),startAt:DateTime(2026,12,1),
   day:12,goalLinked:false,alreadyPaid:false),isFalse);
  expect(WaffraFinancialInsights.pendingCurrentMonth(
   now:DateTime(2026,11,4),startAt:DateTime(2026,11,16),
   day:16,goalLinked:true,alreadyPaid:false),isTrue);
  expect(WaffraFinancialInsights.pendingCurrentMonth(
   now:DateTime(2026,11,4),startAt:DateTime(2026,11,1),
   day:16,goalLinked:false,alreadyPaid:true),isFalse);
 });
 test('M444 selected budget thresholds 50/70/100 honored',(){
  expect(WaffraFinancialInsights.reachedBudgetThreshold(
   spent:52,budget:100,alertPercent:50),isTrue);
  expect(WaffraFinancialInsights.reachedBudgetThreshold(
   spent:52,budget:100,alertPercent:70),isFalse);
  expect(WaffraFinancialInsights.reachedBudgetThreshold(
   spent:100,budget:100,alertPercent:100),isTrue);
  expect(WaffraFinancialInsights.reachedBudgetThreshold(
   spent:10,budget:0,alertPercent:50),isFalse);
 });
}

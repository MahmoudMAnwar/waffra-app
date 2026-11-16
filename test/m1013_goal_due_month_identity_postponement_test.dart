import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_reminders.dart';
import 'package:waffra/waffra_recurring_policy.dart';

/// M1013 / #729: pure due identity, notification lifecycle and replay checks.
void main() {
 test('M1013 SQLCipher due identity matches Home for every month',(){
  final source=File('lib/storage/waffra_fresh_finance_domain_repository.dart')
   .readAsStringSync();
  final writer=source.split('Future<WaffraGoalDueSqlReceipt> settleLinkedGoalDue({')[1];
  expect(writer,contains("final expectedDue = 'rec_"));
  expect(writer,contains("'${dueDate.month}'"));
  expect(writer,isNot(contains("dueDate.month.toString().padLeft(2,'0')")));
  for(var month=1;month<=12;month++){
   final due=DateTime(2026,month,16);
   final key=WaffraRecurringPolicy.entryId('house',due);
   expect(key,'rec_house_2026_$month');
  }
 });

 test('M1013 postponed goal reminders use the NEW due date only',(){
  final postponed=DateTime(2026,11,22);
  final goal=WaffraReminder(id:'house',title:'منزل',day:16,
   startAt:DateTime(2026,11,16),oneTimeDueAt:postponed);
  expect(WaffraReminders.upcomingDueDates(goal,DateTime(2026,11,17)),
   [postponed]);
  expect(WaffraReminders.reminderTime(postponed,3),
   DateTime(2026,11,19,9));
  expect(WaffraReminders.reminderTime(postponed,2),
   DateTime(2026,11,20,9));
  expect(WaffraReminders.reminderTime(postponed,1),
   DateTime(2026,11,21,9));
  expect(WaffraReminders.upcomingDueDates(goal,DateTime(2026,11,23)),
   isEmpty);
 });

 test('M1013 paid goal dues never get fresh OS reminders',(){
  final source=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  final schedule=source.split(' Future<void> syncRecurringReminders()async {')[1]
   .split(' Future<void> toggleRecurringReminders(')[0];
  expect(schedule,contains('final paidGoalDueKeys=<String>{'));
  expect(schedule,contains("if(entry.sourceType=='goal_due')entry.id"));
  expect(schedule,contains('!paidGoalDueKeys.contains('));
  expect(schedule,contains('DateTime.tryParse(recurringPostponed['));
  expect(schedule,contains('WaffraRecurringPolicy.entryId(r.id,r.startAt)'));
  final writer=File('lib/storage/waffra_fresh_finance_domain_repository.dart')
   .readAsStringSync();
  expect(writer,contains("schedule['active'] = false;"));
 });

 test('M1013 Postpone reschedules after commit and cannot debit',(){
  final source=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  final postpone=source.split("}else if(action=='postpone'){")[1]
   .split('}else{return;}')[0];
  expect(postpone,contains('recurringPostponed[id]=selected.toIso8601String();'));
  expect(postpone,contains("operation:'recurring-postpone'"));
  expect(postpone,contains('if(mounted)await syncRecurringReminders();'));
  expect(postpone.indexOf("operation:'recurring-postpone'"),
   lessThan(postpone.indexOf('if(mounted)await syncRecurringReminders();')));
  expect(postpone,isNot(contains('settleLinkedGoalDue(')));
  expect(postpone,isNot(contains('entries.insert(')));
 });

 test('M1013 ledger always requires Paid confirmation and idempotent due key',(){
  final due=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  expect(due,contains("if(action=='paid'){"));
  expect(due,contains('userConfirmed:true,selectedAccountId:chosenId'));
  expect(due,contains('alreadyPaid:entries.any((e)=>e.id==id)'));
  expect(due,contains('goalLinkedOnly&&r.linkedGoalId==null'));
  final encrypted=File('lib/storage/waffra_verified_goal_due_snapshot_writer.dart')
   .readAsStringSync();
  expect(encrypted,contains('if (receipt.alreadySettled)'));
  expect(encrypted,contains('final cashRequired=amountMinor-'));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_reminders.dart';

/// M1012/#729: no money can be posted from reminder scheduling.
void main(){
 test('M1012 one-time goal due produces only its own due date',(){
  final item=WaffraReminder(id:'house',title:'منزل',day:16,
   startAt:DateTime(2026,11,16),oneTimeDueAt:DateTime(2026,11,16));
  final due=WaffraReminders.upcomingDueDates(item,DateTime(2026,11,12));
  expect(due,[DateTime(2026,11,16)]);
  expect(WaffraReminders.upcomingDueDates(item,DateTime(2026,11,16)),
   isEmpty);
  expect(WaffraReminders.upcomingDueDates(item,DateTime(2026,12,10)),
   isEmpty);
 });

 test('M1012 three distinct reminders before November 16, at 9 local',(){
  final due=DateTime(2026,11,16);
  expect(WaffraReminders.reminderTime(due,3),DateTime(2026,11,13,9));
  expect(WaffraReminders.reminderTime(due,2),DateTime(2026,11,14,9));
  expect(WaffraReminders.reminderTime(due,1),DateTime(2026,11,15,9));
  expect(() => WaffraReminders.reminderTime(due,0),throwsArgumentError);
  expect(() => WaffraReminders.reminderTime(due,4),throwsArgumentError);
 });

 test('M1012 3/2/1 calendar days cross month and leap year safely',(){
  final march=DateTime(2028,3,1);
  expect(WaffraReminders.reminderTime(march,3),DateTime(2028,2,27,9));
  expect(WaffraReminders.reminderTime(march,2),DateTime(2028,2,28,9));
  expect(WaffraReminders.reminderTime(march,1),DateTime(2028,2,29,9));
  final newYear=DateTime(2027,1,2);
  expect(WaffraReminders.reminderTime(newYear,3),DateTime(2026,12,30,9));
 });

 test('M1012 Android local reminders are opt-in, 3/2/1, not automatic payment',(){
  final reminders=File('lib/waffra_reminders.dart').readAsStringSync();
  final due=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  expect(reminders,contains('for(final daysBefore in const <int>[3,2,1])'));
  expect(reminders,contains('if(!remindAt.isAfter(now.add(const Duration(minutes:2))))continue;'));
  expect(reminders,contains('stableId(item.id,(due.year*12+due.month)*4+daysBefore)'));
  expect(reminders,contains('_cancelRecurringOnly()'));
  expect(reminders,contains('isManagedRecurringRequest'));
  expect(reminders,contains('tz.TZDateTime.from(remindAt,tz.local)'));
  expect(reminders,isNot(contains('settleLinkedGoalDue(')));
  expect(reminders,isNot(contains('commitConfirmedManual(')));
  expect(due,contains('if(!recurringRemindersEnabled)return;'));
  expect(due,contains('WaffraReminders.schedule('));
 });

 test('M1012 verified Home does not suppress explicit goal due confirmation',(){
  final startup=File('lib/waffra_home_finance_startup.part.dart')
   .readAsStringSync();
  final dues=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  expect(startup,contains('await applyRecurring(goalLinkedOnly:false);'));
  expect(startup,isNot(contains('goalLinkedOnly:verifiedEncryptedStartup')));
  expect(startup,isNot(contains('if(!verifiedEncryptedStartup)await applyRecurring();')));
  expect(startup.indexOf('setState(()=>ready=true);'),
   lessThan(startup.indexOf('await applyRecurring(goalLinkedOnly:false);')));
  expect(dues,contains('Future<void> applyRecurring({bool goalLinkedOnly=false})async {'));
  expect(dues,contains('if(goalLinkedOnly&&r.linkedGoalId==null)continue;'));
  expect(dues,contains("if(action=='paid'){"));
  expect(dues,contains("if(action=='postpone'){"));
  expect(dues,contains("'later'"));
  expect(dues,contains('_financeAuthority.settleLinkedGoalDue('));
  expect(dues,contains('userConfirmed:true,selectedAccountId:chosenId'));
  expect(dues,contains('alreadyPaid:entries.any((e)=>e.id==id)'));
  expect(dues,isNot(contains('WaffraReminders.schedule(\n     entries')));
 });

 test('M1012 settings still need explicit opt-in and Android OS permission',(){
  final due=File('lib/waffra_home_finance_persistence_due.part.dart')
   .readAsStringSync();
  final page=File('lib/waffra_home_goals_recurring_pages.part.dart')
   .readAsStringSync();
  expect(due,contains('WaffraReminders.requestPermission()'));
  expect(due,contains('WaffraReminders.alreadyPermitted()'));
  expect(due,contains('_financeAuthority.setRecurringReminderPreference(enabled)'));
  expect(page,contains('toggleRecurringReminders(!recurringRemindersEnabled)'));
 });
}

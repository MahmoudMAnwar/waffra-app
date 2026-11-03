import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart' show SavingGoal, RecurringBill;
import '../lib/waffra_financial_insights.dart';
import '../lib/waffra_reminders.dart';

void main(){
 group('M414 goal progress alerts',(){
  test('fixed goal retains independent alert configuration after JSON reload',(){
   final original=SavingGoal(id:'goal1',name:'Rent',target:5000,saved:1000,
    alertEnabled:true,alertPercent:60);
   final restored=SavingGoal.fromJson(original.toJson());
   expect(restored.alertEnabled,isTrue);
   expect(restored.alertPercent,60);
   expect(restored.target,5000);
   expect(restored.saved,1000);
   expect(restored.copy(active:false).alertEnabled,isTrue);
   expect(restored.copy(alertEnabled:false).active,isTrue);
  });
  test('legacy goals opt out without changing saved money',(){
   final data=SavingGoal(id:'old',name:'Old',target:1000,saved:350).toJson()
    ..remove('alertEnabled')..remove('alertPercent');
   final restored=SavingGoal.fromJson(data);
   expect(restored.alertEnabled,isFalse);
   expect(restored.alertPercent,75);
   expect(restored.saved,350);
  });
  test('open goals never have a percentage even with malformed old preference',(){
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(
    0,900,0,50),0);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(
    0,900,-1,50),0);
   final open=SavingGoal(id:'open',name:'Open',target:0,saved:900,
    alertEnabled:true,alertPercent:50);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(
    0,open.saved,open.target,open.alertPercent,
    enabled:open.active&&open.alertEnabled),0);
  });
  test('notify only on forward crossing the exact chosen milestone',(){
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(490,510,1000,50),50);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(510,520,1000,50),0);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(900,1100,1000,50),100);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(700,800,1000,75,
    enabled:false),0);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(900,950,1000,75),0);
   expect(WaffraFinancialInsights.newlyCrossedGoalStage(1100,1200,1000,75),0);
  });
  test('goal threshold preference can be changed without moving money',(){
   final g=SavingGoal(id:'g',name:'Home',target:3000,saved:400,
    alertPercent:90);
   final changed=g.copy(alertEnabled:true,alertPercent:50);
   expect(changed.target,3000);
   expect(changed.saved,400);
   expect(changed.active,isTrue);
   expect(SavingGoal.fromJson(changed.toJson()).alertPercent,50);
  });
 });
 group('M414 recurring reminder switch',(){
  test('reminders can be paused without stopping the financial rule',(){
   final b=RecurringBill(id:'r',title:'Rent',category:'Housing',
    amount:1000,income:false,day:2,reminderEnabled:true);
   final reminderOff=RecurringBill.fromJson(
    b.copy(reminderEnabled:false).toJson());
   expect(reminderOff.reminderEnabled,isFalse);
   expect(reminderOff.active,isTrue);
   expect(reminderOff.amount,1000);
   expect(reminderOff.day,2);
   expect(reminderOff.copy(active:false).reminderEnabled,isFalse);
   expect(reminderOff.copy(active:true).reminderEnabled,isFalse);
  });
  test('old recurring entries retain opt-in flag, no dates or values change',(){
   final input=RecurringBill(id:'old',title:'Income',
    category:'Salary',amount:1900,income:true,day:12).toJson()
    ..remove('reminderEnabled');
   final old=RecurringBill.fromJson(input);
   expect(old.reminderEnabled,isTrue);
   expect(old.income,isTrue);
   expect(old.amount,1900);
   expect(old.day,12);
  });
  test('edited recurring preserves item reminder state',(){
   final original=RecurringBill(id:'r',title:'Electricity',category:'Home',
    amount:200,income:false,day:10,reminderEnabled:false);
   final edited=original.copy(amount:250,title:'New bill');
   expect(RecurringBill.fromJson(edited.toJson()).reminderEnabled,isFalse);
   expect(edited.active,isTrue);
  });
 });
 group('M414 Android local notification helpers',(){
  test('stable IDs are consistent across relaunches',(){
   expect(WaffraReminders.stableId('goal:g:1000.0:75',0),
    WaffraReminders.stableId('goal:g:1000.0:75',0));
   expect(WaffraReminders.stableId('recurring:r',0),
    isNot(WaffraReminders.stableId('goal:g:1000.0:75',0)));
  });
  test('due dates clamp to actual month end, no fake banking events',(){
   expect(WaffraReminders.dueDate(DateTime(2026,2,1),31),
    DateTime(2026,2,28));
  });
 });
}

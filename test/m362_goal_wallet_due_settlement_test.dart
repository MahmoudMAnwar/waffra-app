import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_goal_due_policy.dart';
import 'package:waffra/waffra_recurring_policy.dart';

void main(){
 test('M362 goal savings can exceed current cash without an artificial cap',(){
  final ledger=[MoneyEntry(id:'cash',title:'راتب',
   category:'الراتب',amount:100,income:true,date:DateTime(2026,11,1))];
  final before=[SavingGoal(id:'goal',name:'رحلة',target:500,saved:80)];
  expect(waffraAvailableCash(ledger,before),100);
  final after=[before.single.copy(saved:180)];
  expect(waffraGoalWalletBalance(after),180);
  expect(waffraAvailableCash(ledger,after),100);
  expect(ledger.length,1,reason:'Earmarking is never an expense');
 });

 test('M362 settle fully from goal wallet exactly once in total money',(){
  final plan=WaffraGoalDueAllocation.allocate(dueAmount:200,goalSaved:300);
  expect(plan.amount,200);
  expect(plan.fromGoalWallet,200);
  expect(plan.fromCurrentBalance,0);
  expect(plan.remainingGoalSavings,100);
  final before=[MoneyEntry(id:'salary',title:'salary',category:'income',
   amount:1000,income:true,date:DateTime(2026,11,1))];
  final after=[...before,MoneyEntry(id:'rec_goal_2026_11',title:'goal paid',
   category:'سكن / إيجار شهري',amount:plan.amount,income:false,
   date:DateTime(2026,11,15),sourceType:'goal_due',
   goalWalletPaidMinor:plan.fromGoalMinor)];
  final goalBefore=[SavingGoal(id:'g',name:'goal',target:200,saved:300)];
  final goalAfter=[goalBefore.single.copy(saved:plan.remainingGoalSavings)];
  expect(waffraAvailableCash(before,goalBefore),1000);
  expect(waffraAvailableCash(after,goalAfter),1000);
  expect(waffraGoalWalletBalance(goalAfter),100);
  expect(after.length,2);
  expect(MoneyEntry.fromJson(after.last.toJson()).goalWalletPaidMinor,20000);
 });

 test('M362 shortfall only comes from spendable balance',(){
  final plan=WaffraGoalDueAllocation.allocate(dueAmount:250,goalSaved:200);
  expect(plan.fromGoalWallet,200);
  expect(plan.fromCurrentBalance,50);
  expect(plan.remainingGoalSavings,0);
  expect(plan.fromGoalWallet+plan.fromCurrentBalance,plan.amount);
 });

 test('M362 amounts retain exact halalas and reject invalid data',(){
  final plan=WaffraGoalDueAllocation.allocate(dueAmount:135.75,goalSaved:99.25);
  expect(plan.fromGoalWallet,99.25);
  expect(plan.fromCurrentBalance,36.50);
  expect(plan.remainingGoalSavings,0);
  expect(() => WaffraGoalDueAllocation.allocate(dueAmount:1.234,goalSaved:1),
   throwsArgumentError);
  expect(() => WaffraGoalDueAllocation.allocate(dueAmount:1,goalSaved:-1),
   throwsArgumentError);
 });

 test('M362 one-time goal due identity stays in original month',(){
  final due=DateTime(2026,11,13);
  final id=WaffraRecurringPolicy.entryId('rent-goal',due);
  expect(id,'rec_rent-goal_2026_11');
  expect(WaffraRecurringPolicy.isOutstanding(due:due,
   today:DateTime(2026,12,5),startAt:due,alreadyPaid:false),isTrue);
  expect(WaffraRecurringPolicy.isOutstanding(due:due,
   today:DateTime(2026,12,5),startAt:due,alreadyPaid:true),isFalse);
 });

 test('M362 due-date handler confirms before coupling goal, ledger, recurrence',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('WaffraGoalDueAllocation.allocate('));
  expect(main,contains('sourceType:\'goal_due\''));
  expect(main,contains('recurring[scheduleIndex]=currentSchedule.single.copy(active:false)'));
  expect(main,contains('await persist(route:WaffraFinanceRoute.transactionEdit,'));
  expect(main,contains('userConfirmed:true'));
  expect(main,isNot(contains('if(r.linkedGoalId!=null)continue;')));
  expect(main,contains('if(entries.any((e)=>e.id==id))continue;'));
 });
}

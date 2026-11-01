import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_category_catalog.dart';
import 'package:waffra/waffra_category_english.dart';

void main() {
 test('M343 legacy goal and recurring snapshots remain readable',(){
  final legacyGoal=SavingGoal.fromJson({
   'id':'old','name':'إيجار','target':5000,'saved':1000});
  expect(legacyGoal.dueDate,isNull);
  final deadline=DateTime(2027,5,1);
  final linked=SavingGoal(id:'goal-1',name:'إيجار',target:5000,
   saved:1000,dueDate:deadline);
  expect(linked.toJson()['dueDate'],deadline.toIso8601String());
  expect(SavingGoal.fromJson(linked.toJson()).dueDate,deadline);
  final funded=linked.copy(saved:1200);
  expect(funded.dueDate,deadline);
  expect(funded.target,5000);
  expect(funded.saved,1200);
  final legacyRecurring=RecurringBill.fromJson({
   'id':'old-recurring','title':'إيجار','category':'سكن / إيجار شهري',
   'amount':5000,'income':false,'day':1,'startAt':deadline.toIso8601String()});
  expect(legacyRecurring.linkedGoalId,isNull);
  final recurrence=RecurringBill(id:'rec-goal-1',title:'استحقاق إيجار',
   category:'سكن / إيجار شهري',amount:5000,income:false,day:1,
   startAt:deadline,linkedGoalId:linked.id);
  expect(RecurringBill.fromJson(recurrence.toJson()).linkedGoalId,linked.id);
  expect(recurrence.copy(active:false).linkedGoalId,linked.id);
  expect(recurrence.withCategory('الأسرة / مصروف البيت').linkedGoalId,linked.id);
 });

 test('M344 assigned budgets count only explicitly linked expenses',(){
  final food=BudgetCategory(id:'food',name:'مطاعم وكافيهات',icon:'restaurant',
   color:0xff087a54,income:false,budget:2500,budgetLabel:'ميزانية الأكل');
  final meal=BudgetCategory(id:'meal',name:'مطاعم وكافيهات / وجبات سريعة',
   icon:'restaurant',color:0xff087a54,income:false,parentId:'food');
  final fuel=BudgetCategory(id:'fuel',name:'مواصلات / بنزين',
   icon:'car',color:0xff087a54,income:false,budget:1000,budgetLabel:'ميزانية البنزين');
  final date=DateTime(2026,11,1);
  MoneyEntry entry(String id,String cat,double n,bool income,
      {DateTime? when,String? budgetId})=>
   MoneyEntry(id:id,title:'اختبار',category:cat,amount:n,
    income:income,date:when??date,budgetId:budgetId);
  final entries=[
   entry('1',meal.name,70,false,budgetId:'food'),
   entry('2',fuel.name,30,false,budgetId:'fuel'),
   entry('3',meal.name,900,true,budgetId:'food'),
   entry('4',meal.name,40,false,when:DateTime(2026,10,30),budgetId:'food'),
   entry('5',meal.name,50,false), // old expense: no retroactive auto-link
   entry('6',meal.name,20,false,budgetId:'fuel'), // explicitly reassigned
  ];
  expect(waffraNamedBudgetSpent(entries,[food,meal,fuel],food,date),70);
  expect(waffraNamedBudgetSpent(entries,[food,meal,fuel],fuel,date),50);
  expect(entries[4].budgetId,isNull);
  final reassigned=entries[4].withBudget('food');
  expect(reassigned.budgetId,'food');
  expect(reassigned.amount,50);
  expect(reassigned.date,date);
  expect(reassigned.toJson()['budgetId'],'food');
  expect(MoneyEntry.fromJson(reassigned.toJson()).budgetId,'food');
  expect(MoneyEntry.fromJson(entries[4].toJson()).budgetId,isNull);
  expect(BudgetCategory.fromJson(food.toJson()).budgetLabel,'ميزانية الأكل');
  expect(food.copy(budget:3000).budgetLabel,'ميزانية الأكل');
 });

 test('M344 goal earmarks move between available and goals wallet without double expense',(){
  final now=DateTime(2026,11,1);
  MoneyEntry tx(String id,double amount,bool income)=>MoneyEntry(
   id:id,title:'test',category:income?'حوالات واردة':'سكن / إيجار شهري',
   amount:amount,income:income,date:now);
  final ledger=[tx('income',5000,true)];
  final initial=[SavingGoal(id:'rent',name:'إيجار',target:5000,saved:0)];
  expect(waffraGoalWalletBalance(initial),0);
  expect(waffraAvailableCash(ledger,initial),5000);
  final allocated=[initial.single.copy(saved:1000)];
  expect(waffraGoalWalletBalance(allocated),1000);
  expect(waffraAvailableCash(ledger,allocated),5000);
  final released=[allocated.single.copy(saved:0)];
  expect(waffraAvailableCash(ledger,released),5000);
  final paid=[...ledger,tx('paid-rent',1000,false)];
  expect(waffraAvailableCash(paid,released),4000);
  // An independent goals-wallet allocation never changes ledger cash.
  expect(ledger.length,1);
 });

 test('M343 official household labels are bilingual and do not add roots',(){
  expect(waffraCategoryCatalog.length,79);
  expect(waffraCategoryCatalog.fold<int>(0,(n,g)=>n+g.subcategories.length),975);
  expect(waffraEnglishCategoryCatalogComplete,isTrue);
  final family=waffraCategoryCatalog.singleWhere((c)=>c.id=='family');
  final incoming=waffraCategoryCatalog.singleWhere((c)=>c.id=='incoming-transfers');
  expect(family.subcategories,contains('مصروف البيت'));
  expect(incoming.subcategories,contains('مخصص مصروف البيت'));
  expect(waffraEnglishCategoryLabel('الأسرة / مصروف البيت'),
   contains('Household spending'));
  expect(waffraEnglishCategoryLabel('حوالات واردة / مخصص مصروف البيت'),
   contains('Household allowance received'));
 });

 test('M343 goal/recurring UI uses one saved total and budget remains independent',(){
  final app=File('lib/main.dart').readAsStringSync();
  final link=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(app,contains('waffra_goal_recurring_actions.part.dart'));
  expect(app,contains('await this._ensureLinkedRecurringForGoal(g);'));
  expect(app,contains('this.editGoal(g)'));
  expect(app,contains('recurringDialog(initial:r)'));
  expect(app,contains('onChanged:initial?.linkedGoalId!=null?null'));
  final directory=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
  expect(directory,contains('editBudgetForCategory(b)'));
  expect(app,contains('goal.saved/goal.target'));
  expect(app,contains('waffraNamedBudgetSpent(entries,categories,selected,today)'));
  expect(link,contains('linkedGoalId:goal.id'));
  expect(link,contains('operation:\'goal-edit\''));
  expect(link,contains('operation:\'goal-recurring-link\''));
  expect(link,isNot(contains('entries.add(')));
  expect(app,contains("sourceType:'goal_due'"));
  expect(app,contains('WaffraGoalDueAllocation.allocate('));
  expect(app,contains('reviewSmsBudgetLinks(additions)'));
  expect(app,contains('offerHistoricBudgetLink(updated.single)'));
  expect(directory,contains('deleteNamedBudget(b)'));
  expect(app,contains('releaseGoalFunds(SavingGoal goal)'));
  expect(app,contains('waffraGoalWalletBalance(goals)'));
  expect(app,contains('waffraAvailableCash(entries,goals)'));
 });
}

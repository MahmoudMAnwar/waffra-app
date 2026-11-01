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

 test('M343 separate budgets count only assigned expense categories',(){
  final food=BudgetCategory(id:'food',name:'مطاعم وكافيهات',icon:'restaurant',
   color:0xff087a54,income:false,budget:2500,budgetLabel:'ميزانية الأكل');
  final meal=BudgetCategory(id:'meal',name:'مطاعم وكافيهات / وجبات سريعة',
   icon:'restaurant',color:0xff087a54,income:false,parentId:'food');
  final fuel=BudgetCategory(id:'fuel',name:'مواصلات / بنزين',
   icon:'car',color:0xff087a54,income:false,budget:1000,budgetLabel:'ميزانية البنزين');
  final date=DateTime(2026,11,1);
  MoneyEntry entry(String id,String cat,double n,bool income,{DateTime? when})=>
   MoneyEntry(id:id,title:'اختبار',category:cat,amount:n,
    income:income,date:when??date);
  final entries=[
   entry('1',meal.name,70,false),
   entry('2',fuel.name,30,false),
   entry('3',meal.name,900,true),
   entry('4',meal.name,40,false,when:DateTime(2026,10,30)),
  ];
  expect(waffraNamedBudgetSpent(entries,[food,meal,fuel],food,date),70);
  expect(waffraNamedBudgetSpent(entries,[food,meal,fuel],fuel,date),30);
  expect(BudgetCategory.fromJson(food.toJson()).budgetLabel,'ميزانية الأكل');
  expect(food.copy(budget:3000).budgetLabel,'ميزانية الأكل');
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
  expect(app,contains('goal.saved/goal.target'));
  expect(app,contains('waffraNamedBudgetSpent(entries,categories,selected,today)'));
  expect(link,contains('linkedGoalId:goal.id'));
  expect(link,contains('operation:\'goal-edit\''));
  expect(link,contains('operation:\'goal-recurring-link\''));
  expect(link,isNot(contains('entries.add(')));
 });
}

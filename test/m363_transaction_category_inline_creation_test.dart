import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M363 both category dropdowns create styled main/child categories',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains("'waffra-inline-create-main-category'"));
  expect(source,contains('if(allowCreate&&!leafLabels)'));
  expect(source,contains("'waffra-inline-create-subcategory'"));
  expect(source,contains('if(allowCreate&&leafLabels)'));
  expect(source,contains('final created=await categoryDialog('));
  expect(source,contains('income:typeIncome,parentId:categoryParentId'));
  expect(source,contains('operation:\'transaction-category-picker-create\''));
  expect(source,contains('allowCreate:true,typeIncome:income,parentId:selectedParentId'));
  expect(source,contains('leafLabels:true,allowCreate:true,typeIncome:income'));
  expect(source,isNot(contains("'waffra-entry-new-subcategory'")));
  expect(source,isNot(contains("label:const WaffraText('قسم فرعي جديد')")));
 });

 test('M363 original icon, color and duplicate protections are reused',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('categoryDialog({BudgetCategory? initial'));
  expect(source,contains('WaffraValidators.uniqueCategory(created.name,'));
  expect(source,contains('icon:Icon(categoryIcon(x),color:icon==x?emerald:null)'));
  expect(source,contains('child:CircleAvatar(radius:15,backgroundColor:Color(x)'));
 });

 test('M363 transaction edit keeps same selectable active budget as create',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('String? selectedBudgetId=initial?.budgetId'));
  expect(source,contains("'waffra-entry-budget-'"));
  expect(source,contains("'__create_budget__'"));
  expect(source,contains("'__manage_budgets__'"));
  expect(source,isNot(contains("'waffra-entry-search-budgets'")));
  expect(source,isNot(contains("'waffra-entry-create-named-budget'")));
  expect(source,contains('void assignBudgetInsideEditor(String? pickedId)'));
  final assign=source.substring(source.indexOf('void assignBudgetInsideEditor('),
   source.indexOf('Widget dateAction()',source.indexOf('void assignBudgetInsideEditor(')));
  expect(assign,isNot(contains('selectedParentId=matches.single.parentId')));
  expect(assign,isNot(contains('category=matches.single.name')));
 });

 test('M363 bulk bank review also receives inline parent/child creation',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('allowCreate:true,typeIncome:income,parentId:smsParentId'));
  expect(source,contains('leafLabels:true,allowCreate:true,'));
  expect(source,contains('smsParentId=leaf.single.parentId'));
 });

 test('M362 verified encrypted goal spend uses one atomic wallet-and-ledger writer',(){
  final source=File('lib/main.dart').readAsStringSync();
  // The atomic goal due writer has now been implemented. Keep a positive
  // source-level witness instead of requiring its obsolete fail-closed stub.
  expect(source,contains('_financeAuthority.settleLinkedGoalDue('));
  expect(source,contains('userConfirmed:true,selectedAccountId:chosenId'));
  expect(source,contains('WaffraRuntimeFinanceBackend.verifiedEncrypted'));
  expect(source,contains("if(e.sourceType=='goal_due')"));
  expect(source,contains("readOnly:initial?.sourceType=='goal_due'"));
  expect(source,contains('recurring[scheduleIndex]=currentSchedule.single.copy(active:false)'));
 });

 test('M362 a short available balance warns and permits funding',(){
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> fundGoal(SavingGoal g)async');
  final end=source.indexOf('IconData goalIcon(',start);
  final fund=source.substring(start,end);
  expect(fund,contains('if(n>available)'));
  expect(fund,contains('showWaffraDialog<bool>'));
  expect(fund,contains('if(acknowledged!=true||!mounted)return;'));
  expect(fund,contains('goals[i]=current.copy(saved:current.saved+n)'));
  expect(fund,isNot(contains('Insufficient available balance to allocate')));
 });
}

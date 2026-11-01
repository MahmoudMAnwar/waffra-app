import 'dart:io';
import 'package:flutter/material.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main(){
 group('M353 pause/resume named budgets without losing real finance data',(){
  final older=DateTime(2026,10,28);
  final duringPause=DateTime(2026,11,5);
  final afterResume=DateTime(2026,11,20);
  BudgetCategory budget()=>BudgetCategory(
    id:'fuel',name:'سيارة / بنزين',income:false,
    icon:'car',color:0xff087a54,budget:200,
    budgetLabel:'وقود السيارة',alertPercent:80);
  MoneyEntry expense(String id,DateTime date,{String? budgetId})=>
    MoneyEntry(id:id,title:'تعبئة وقود',category:'سيارة / بنزين',
      amount:75,income:false,date:date,notes:'معلومة تجريبية',
      sourceType:'manual',budgetId:budgetId);

  test('legacy saved budget defaults to ACTIVE even without new JSON field',(){
   final source={
     'id':'fuel','name':'سيارة / بنزين','icon':'car','color':0xff087a54,
     'income':false,'budget':200,'alertPercent':80,
     'budgetLabel':'وقود السيارة',
   };
   final loaded=BudgetCategory.fromJson(source);
   expect(loaded.budgetActive,isTrue);
   expect(loaded.budget,200);
   expect(loaded.budgetLabel,'وقود السيارة');
  });
  test('corrupt paused flag never silently enables a budget',(){
   final input=budget().toJson();
   input['budgetActive']='corrupt';
   expect(BudgetCategory.fromJson(input).budgetActive,isFalse);
  });
  test('pausing is metadata-only and retains historic linked transactions',(){
   final enabled=budget();
   final old=expense('existing-1',older,budgetId:enabled.id);
   final paused=enabled.copy(budgetActive:false);
   expect(paused.budgetActive,isFalse);
   expect(paused.id,enabled.id);
   expect(paused.name,enabled.name);
   expect(paused.budget,200);
   expect(paused.budgetLabel,enabled.budgetLabel);
   expect(paused.alertPercent,80);
   expect(BudgetCategory.fromJson(paused.toJson()).budgetActive,isFalse);
   expect(old.budgetId,'fuel');
   expect(old.amount,75);
   expect(old.date,older);
   expect(waffraNamedBudgetSpent([old],[paused],paused,older),75);
  });
  test('operations while paused stay unlinked after reactivation',(){
   final paused=budget().copy(budgetActive:false);
   final old=expense('existing-1',older,budgetId:paused.id);
   final addedWhilePaused=expense('manual-while-paused',duringPause);
   // Manual, bank and OCR must all save budgetId:null while paused.
   expect(addedWhilePaused.budgetId,isNull);
   final resumed=BudgetCategory.fromJson(paused.copy(
     budgetActive:true).toJson());
   expect(resumed.budgetActive,isTrue);
   expect(addedWhilePaused.budgetId,isNull,
     reason:'Reactivating never retroactively links an expense');
   expect(old.budgetId,'fuel',
     reason:'Pausing or resuming cannot unlink earlier allocations');
   expect(waffraNamedBudgetSpent([old,addedWhilePaused],[resumed],
     resumed,duringPause),0);
   final accepted=addedWhilePaused.withBudget(resumed.id);
   expect(accepted.budgetId,'fuel');
   expect(accepted.amount,addedWhilePaused.amount);
   expect(accepted.date,addedWhilePaused.date);
   expect(accepted.notes,addedWhilePaused.notes);
   expect(waffraNamedBudgetSpent([accepted],[resumed],resumed,duringPause),75);
   expect(waffraNamedBudgetSpent([expense('new',afterResume)],
     [resumed],resumed,afterResume),0);
  });
  test('deleting budget is different from pause: pause preserves source data',(){
   final budgetBefore=budget();
   final paused=budgetBefore.copy(budgetActive:false);
   expect(paused.budget,greaterThan(0));
   expect(paused.budgetLabel,isNotNull);
   final deleted=paused.copy(budget:0,clearBudget:true);
   expect(deleted.budget,0);
   expect(deleted.budgetLabel,isNull);
   expect(paused.budget,200);
  });
 });

 test('M353 all screens gate NEW budget assignment and retain old links',(){
  final home=File('lib/main.dart').readAsStringSync();
  final cats=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(home,contains('budgetActive:j[\'budgetActive\']==null?true:j[\'budgetActive\']==true'));
  expect(home,contains("budgetActive:budgetActive??this.budgetActive"));
  expect(home,contains('Future<void> setNamedBudgetActive('));
  expect(home,contains('operation:\'named-budget-active-toggle\''));
  expect(home,contains("Key('waffra-named-budget-enabled-switch')"));
  expect(home,contains('value:selected.budgetActive'));
  expect(home,contains('onChanged:WaffraHaptics.selection('));
  expect(home,contains('c.budget>0&&c.budgetActive'));
  expect(home,contains('initial!=null&&initial.budgetId==c.id'));
  expect(home,contains('if(updated.length==1&&updated.single.budgetActive)'));
  expect(home,contains('budgetId:income?null:(categories.any'));
  expect(home,contains('A selected budget was paused. Review the batch again.'));
  expect(cats,contains('Budget paused'));
 });

 test('M353 transaction details warn with optional link after resume',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains("Key('waffra-transaction-budget-unlinked-warning')"));
  expect(home,contains('if(entry.budgetId==null)'));
  expect(home,contains("Key('waffra-transaction-link-budget-action')"));
  expect(home,contains('onLinkBudget:entry.income||entry.budgetId!=null?null:()'));
  expect(home,contains('unawaited(assignExistingExpenseToBudget(entry))'));
  expect(home,contains('b.budget>0&&b.budgetActive'));
  expect(home,contains('operation:\'retroactive-opt-in-budget-link\''));
  expect(home,contains('if(ok!=true||!mounted)return;'));
 });

 test('M353 paused budget toggles never touch original finance transaction',(){
  final home=File('lib/main.dart').readAsStringSync();
  final scope=home.split('Future<void> setNamedBudgetActive(').last
    .split('Future<void> editBudgetForCategory(').first;
  expect(scope,contains('categories[i]=categories[i].copy(budgetActive:enabled)'));
  expect(scope,isNot(contains('entries.add(')));
  expect(scope,isNot(contains('entries.clear(')));
  expect(scope,isNot(contains('entries.remove(')));
  expect(scope,isNot(contains('withBudget(')));
  expect(scope,contains('_persistModuleOrReload('));
 });

 testWidgets('M353 unlinked expense details show warning and link action',
  (tester)async{
  waffraLanguage.value='ar';
  var clicked=false;
  final old=MoneyEntry(id:'old',title:'مصروف قديم',
   category:'سيارة / بنزين',amount:75,income:false,
   date:DateTime(2026,11,1));
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:WaffraTransactionDetailsDialog(
    entry:old,onClose:(){},onLinkBudget:()=>clicked=true))));
  expect(find.byKey(const Key('waffra-transaction-budget-unlinked-warning')),
    findsOneWidget);
  final action=find.byKey(const Key('waffra-transaction-link-budget-action'));
  expect(action,findsOneWidget);
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
  expect(clicked,isTrue);
  expect(old.budgetId,isNull,
   reason:'The detail UI must only trigger confirmation, not save a link');
  expect(tester.takeException(),isNull);
 });

 testWidgets('M353 existing paused linked expense retains badge without warning',
  (tester)async{
  waffraLanguage.value='ar';
  final older=MoneyEntry(id:'existing',title:'مصروف قبل الإيقاف',
   category:'سيارة / بنزين',amount:75,income:false,
   date:DateTime(2026,10,15),budgetId:'fuel');
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:WaffraTransactionDetailsDialog(entry:older,onClose:(){},
    linkedBudgetName:'ميزانية الوقود',linkedBudgetPaused:true))));
  expect(find.byKey(const Key('waffra-transaction-budget-unlinked-warning')),
    findsNothing);
  expect(find.byKey(const Key('waffra-transaction-link-budget-action')),
    findsNothing);
  expect(find.textContaining('متوقفة مؤقتًا'),findsWidgets);
  expect(older.budgetId,'fuel');
  expect(tester.takeException(),isNull);
 });

}

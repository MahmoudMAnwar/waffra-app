import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_budget_template_catalog.dart';

void main(){
 final main=File('lib/main.dart').readAsStringSync();
 final budget=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
 final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
 final clones=File('lib/waffra_clone_goal_recurring.part.dart').readAsStringSync();

 test('M380 modal source must not refresh disposed sheet',(){
  expect(budget,contains('DraggableScrollableSheet('));
  expect(budget,contains('if(ctx.mounted)refresh(operation);'));
  expect(budget,contains("ValueKey<String>('waffra-my-budgets-directory-sheet')"));
  expect(budget,contains('collapsedShape:const RoundedRectangleBorder(side:BorderSide.none)'));
 });

 test('M381-M385 saved cards and suggestion groups are independent',(){
  expect(budget,contains("'waffra-budget-details-'"));
  expect(budget,contains('initiallyExpanded:false'));
  expect(budget,contains('Switch.adaptive('));
  expect(budget,contains("Key('waffra-budget-active-'"));
  expect(budget,contains('setNamedBudgetActive(b,enabled)'));
  expect(budget,contains("if(view!='mine')"));
  expect(budget,contains("if(view!='suggested')"));
  expect(budget,contains('onTemplateGroupChange(type.id)'));
  expect(waffraBudgetTemplateGroups.length,9);
  expect(waffraBudgetStarterTemplates.length,62);
  final names=<String>{};
  for(final t in waffraBudgetStarterTemplates){
   expect(t.nameAr.trim().isNotEmpty,isTrue);
   expect(names.add(t.nameAr),isTrue);
   expect(waffraBudgetTemplateGroups.any((g)=>g.id==t.group),isTrue);
  }
 });

 test('M386 four menus keep blur, close and stable goals/recurring options',(){
  expect(main,contains('filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7)'));
  expect(main,contains('expanded:addFabExpanded,'));
  expect(main,contains('(tab==0||tab==1||tab==3||tab==4||goalsOpened)'));
  expect(main,contains('if(addFabExpanded){setState(()=>addFabExpanded=false);return true;}'));
  expect(main,contains('_launchAddAction(copyGoalDialog,fromMenu:true)'));
  expect(main,contains('_launchAddAction(copyRecurringDialog,fromMenu:true)'));
 });

 test('M391 copy creates NEW IDs, does not duplicate goal funds or dues',(){
  expect(clones,contains('Future<void> copyGoalDialog()'));
  expect(clones,contains('Future<void> copyRecurringDialog()'));
  expect(clones,contains("raw['goal']"));
  expect(clones,contains("raw['recurring']"));
  expect(clones,contains('linkedGoalId==null'));
  expect(main,contains('goalDialog({SavingGoal? copyFrom})'));
  expect(main,contains('target:n,saved:0,dueDate:selectedDeadline'));
  expect(main,contains('final seed=initial??copyFrom;'));
  expect(main,contains('id:initial?.id??newId()'));
 });

 test('M393 quick actions have borders and >=48dp tap targets',(){
  expect(categories,contains('OutlinedButton.icon('));
  expect(categories,contains('minimumSize:const Size(0,48)'));
  expect(categories,contains('collapsedShape:RoundedRectangleBorder('));
  expect(categories,contains('SwitchListTile.adaptive('));
 });

 test('M395 goals wallet matches Home header geometry',(){
  expect(main,contains('padding:EdgeInsets.fromLTRB(goalWallet?0:14,0,goalWallet?0:14,4)'));
  expect(main,contains("Key(goalWallet?'waffra-goal-wallet-balance-card'"));
 });

 test('M387-M398 remove redundant descriptions but retain security warnings',(){
  expect(main,isNot(contains('اختياري، من غير تغيير القسم')));
  expect(main,contains("'Original bank message':'الرسالة البنكية الأصلية'"));
  expect(main,contains('تعذر فتح الرسالة البنكية المشفّرة'));
  expect(main,contains('يُضاف المبلغ لمحفظة الأهداف دون خصمه تلقائيًا'));
 });

 test('M397 linking budgets is metadata-only and offers create/manage',(){
  expect(main,contains('latest.single.withBudget(selected.id)'));
  expect(main,contains("operation:'retroactive-opt-in-budget-link'"));
  expect(main,contains('showBudgetsDirectorySheet()'));
  expect(main,contains('final id=await chooseBudgetCategory();'));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M1021 / Issue #738: exact screenshot behavior; no money fixtures needed.
void main(){
 final pages=File('lib/waffra_home_goals_recurring_pages.part.dart')
  .readAsStringSync();
 final goal=pages.split(' Widget goalsPage(){')[1]
  .split(' Widget recurringPage(){')[0];
 final dues=pages.split(' Widget recurringPage(){')[1];
 final actions=File('lib/waffra_home_goal_actions.part.dart')
  .readAsStringSync();

 test('every goal card has the same three bottom actions as linked goal dues',(){
  expect(goal,contains("key:Key('m689-goal-card-'+g.id)"));
  for(final label in <String>['Quick deposit','إيداع سريع',
   'Edit goal','تعديل الهدف','Account details','تفاصيل الحساب']){
   expect(dues,contains(label),reason:'Due is visual reference: '+label);
   expect(goal,contains(label),reason:'Missing goal inline action: '+label);
  }
  for(final key in <String>['m1021-goal-deposit-',
   'm1021-goal-edit-','m1021-goal-account-']){
   expect(goal,contains("Key('"+key+"'+g.id)"));
  }
  expect(goal,contains('Expanded(child:TextButton.icon('));
  expect(goal,contains('label:FittedBox(fit:BoxFit.scaleDown'));
  expect(goal,contains('icon:const Icon(Icons.bolt_outlined,size:17)'));
  expect(goal,contains('icon:const Icon(Icons.edit_outlined,size:17)'));
  expect(goal,contains('icon:const Icon(Icons.account_balance_wallet_outlined,size:17)'));
 });

 test('goal card BODY never triggers the old Save now quick-action sheet',(){
  final card=goal.split("key:Key('m689-goal-card-'+g.id)")[1]
   .split('if(goals.isEmpty)Padding')[0];
  expect(card,isNot(contains('onTap:WaffraHaptics.tap(()=>unawaited(_m689GoalActions(g)))')));
  expect(card,isNot(contains('child:InkWell(')));
  expect(card,contains('child:Padding(padding:const EdgeInsets.all(12)'));
  expect(actions,isNot(contains('showModalBottomSheet<void>(')));
  expect(actions,isNot(contains("'Choose an action for this goal'")));
  expect(actions,isNot(contains("'ادخر الآن'")));
 });

 test('deposit guard and financial routes are exactly the due-card semantics',(){
  expect(goal,contains('onPressed:g.active&&(g.target<=0||g.saved<g.target)?'));
  expect(goal,contains('WaffraHaptics.tap(()=>unawaited(fundGoal(g))):null'));
  expect(goal,contains("()=>unawaited(_handleGoalCardAction(g,'edit'))"));
  expect(goal,contains('()=>unawaited(openVerifiedAccounts())'));
  expect(goal,contains("final completed=g.target>0&&g.saved>=g.target;"));
  expect(goal,contains('max(0,g.target-g.saved)'));
  expect(goal,isNot(contains('commitConfirmedSms(')));
  expect(goal,isNot(contains('persist(')));
 });

 test('no loss of release pause and deletion: explicit per-goal manage menu',(){
  expect(goal,contains("Key('m1021-goal-manage-'+g.id)"));
  expect(goal,contains('PopupMenuButton<String>('));
  expect(goal,contains('if(g.saved>0)PopupMenuItem<String>('));
  expect(goal,contains("value:'release'"));
  expect(goal,contains("value:'toggle'"));
  expect(goal,contains("value:'delete'"));
  expect(goal,contains('onSelected:(v)=>unawaited(_m689GoalActions(g,v))'));
  expect(actions,contains("if(action=='release'&&g.saved>0)"));
  expect(actions,contains("await _handleGoalCardAction(g,'release');"));
  expect(actions,contains("if(action=='toggle')await setGoalActive(g,!g.active);"));
  expect(actions,contains("if(action=='delete')await _handleGoalCardAction(g,'delete');"));
  expect(actions,contains('confirmDeletion('));
 });

 test('each filtered goal retains stable identity; due cards remain unmodified',(){
  expect(goal,contains('...ordered.map((g)=>Builder(builder:(_)'));
  expect(goal,contains("key:Key('m689-goal-card-'+g.id)"));
  expect(goal,contains('WaffraApprovedStatusPill(label:stateLabel'));
  expect(goal,contains('controller:_goalsScrollController'));
  expect(goal,contains('waffraSearchAny([g.name,waffraTr(g.name)],goalSearch)'));
  expect(dues,contains("key:Key('m689-due-card-'+r.id)"));
  expect(dues,contains('onPressed:goal.active&&(goal.target<=0||goal.saved<goal.target)?'));
  expect(dues,contains("waffraIsEnglish?'Quick deposit':'إيداع سريع'"));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M393 old goals still active, pause flag persists, and savings never vanish',(){
  final old=SavingGoal.fromJson({
   'id':'old','name':'هدفي القديم','target':5000,'saved':1200,
  });
  expect(old.active,isTrue);
  expect(old.saved,1200);
  final paused=old.copy(active:false);
  expect(paused.active,isFalse);
  expect(paused.target,5000);
  expect(paused.saved,1200);
  final loaded=SavingGoal.fromJson(paused.toJson());
  expect(loaded.id,old.id);
  expect(loaded.saved,1200);
  expect(loaded.active,isFalse);
  expect(waffraGoalWalletBalance([loaded]),1200);
  expect(SavingGoal.fromJson({...paused.toJson(),'active':'invalid'}).active,
   isFalse,reason:'Corrupt active flag must never silently resume a goal');
  expect(waffraAvailableCash([], [loaded]),0);
 });

 test('M393 goal pause is explicit in Quick Actions, with guarded finance writes',(){
  final source=File('lib/main.dart').readAsStringSync();
  final linked=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(source,contains("'waffra-goal-quick-actions-'"));
  expect(source,contains("'waffra-goal-active-switch-'"));
  expect(source,contains("_handleGoalCardAction(g,'edit')"));
  expect(source,contains("_handleGoalCardAction(g,'delete')"));
  expect(source,contains("setGoalActive(g,enabled)"));
  expect(linked,contains('Future<void> setGoalActive('));
  expect(linked,contains("operation:'goal-active-toggle'"));
  expect(linked,contains('if(deadline==null||goal.target<=0||!goal.active)'));
  expect(linked,contains('active:goal.active'));
  expect(linked,contains('active:existing.active'));
  expect(source,contains('saved:saved??this.saved'));
 });

 test('M393 recurring Quick Actions preserve original edit/delete/toggle',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains("'waffra-recurring-quick-actions-'"));
  expect(source,contains("'waffra-recurring-active-switch-'"));
  expect(source,contains("_handleRecurringCardAction(r,'edit')"));
  expect(source,contains("_handleRecurringCardAction(r,'delete')"));
  expect(source,contains('_setRecurringActiveFromCard(r,value)'));
  expect(source,contains("operation:'recurring-active-toggle'"));
  expect(source,contains("operation:'recurring-delete'"));
  expect(source,contains('recurringPostponed.removeWhere('));
 });

 test('M392 saved budget expands details and has clear, independent switch',(){
  final source=File('lib/waffra_budget_directory.part.dart').readAsStringSync();
  expect(source,contains("'waffra-saved-budget-details-'"));
  expect(source,contains("'waffra-budget-activation-'"));
  expect(source,contains('Switch.adaptive('));
  expect(source,contains('value:b.budgetActive'));
  expect(source,contains('await setNamedBudgetActive(b,!b.budgetActive)'));
  expect(source,contains("'waffra-budget-quick-actions-'"));
  expect(source,contains('editBudgetForCategory(b)'));
  expect(source,contains('deleteNamedBudget(b)'));
  expect(source,contains('initiallyExpanded:false'));
  expect(source,contains('MaterialTapTargetSize.padded'));
  expect(source,contains('fontSize:14,fontWeight:FontWeight.w600'));
  expect(source,contains("'waffra-budget-starter-templates'"));
  expect(source,contains('suggestedName:t.name(waffraIsEnglish)'));
 });

 test('M395 search and visible scrollbars do not mutate finance models',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains("'waffra-goals-search'"));
  expect(source,contains("'waffra-recurring-search'"));
  expect(source,contains("controller:_goalsScrollController,thumbVisibility:true"));
  expect(source,contains("controller:_recurringScrollController,thumbVisibility:true"));
  expect(source,contains("waffraSearchAny([g.name,waffraTr(g.name)],goalSearch)"));
  expect(source,contains("waffraSearchAny([r.title,r.category,waffraTr(r.category)],recurringSearch)"));
  expect(source,contains("String goalSearch='',recurringSearch=''"));
 });

 test('M396 new due entries require explicit consent, never silently debit',(){
  final home=File('lib/main.dart').readAsStringSync();
  final linked=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(home,contains('requestedRecurring=await _confirmGoalDueRecurringLink(g)'));
  expect(home,contains('if(requestedRecurring&&mounted)'));
  expect(linked,contains('Future<bool> _confirmGoalDueRecurringLink('));
  expect(linked,contains("Navigator.pop(ctx,false)"));
  expect(linked,contains("Navigator.pop(ctx,true)"));
  expect(linked,contains('No money is deducted now.'));
  expect(linked,contains('if(oldLinked)'));
  expect(linked,contains('await _confirmGoalDueRecurringLink(updated)'));
  final confirm=linked.split('Future<bool> _confirmGoalDueRecurringLink(').last
    .split('Future<bool> _ensureLinkedRecurringForGoal(').first;
  expect(confirm,isNot(contains('entries.add(')));
  expect(confirm,isNot(contains('recurring.add(')));
 });

 test('M394 privacy cloud explicitly allowlists only owner-approved goal active flag',(){
  final goal=SavingGoal(id:'safe',name:'مفتوح',target:0,saved:250,active:false);
  final copy=WaffraCloudSanitizer.sanitize('goal',goal.toJson());
  expect(copy['active'],false);
  expect(copy['target'],0);
  expect(copy['saved'],250);
  expect(()=>WaffraCloudSanitizer.sanitize('goal',{
   ...goal.toJson(),'receiptPath':'/private/receipt.png',
  }),returnsNormally,reason:'Receipt file path is stripped and never synced');
  expect(copy.containsKey('receiptPath'),isFalse);
  expect(()=>WaffraCloudSanitizer.sanitize('goal',{
   ...goal.toJson(),'bankAccount':'secret',
  }),throwsStateError);
 });
}

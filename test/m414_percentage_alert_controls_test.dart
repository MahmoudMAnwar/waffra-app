import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/waffra_financial_insights.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M414 old standalone budgets retain alerts and independent activation',(){
  final old=WaffraNamedBudget(id:'budget:old',name:'Fuel',budget:1000).toJson()
   ..remove('alertsEnabled');
  final restored=WaffraNamedBudget.fromJson(old);
  expect(restored.alertsEnabled,isTrue);
  expect(restored.alertPercent,80);
  final disabled=restored.copy(alertsEnabled:false,alertPercent:75);
  expect(disabled.budgetActive,isTrue);
  expect(disabled.budget,restored.budget);
  expect(disabled.id,restored.id);
  expect(WaffraNamedBudget.fromJson(
   jsonDecode(jsonEncode(disabled.toJson())) as Map<String,dynamic>)
   .alertsEnabled,isFalse);
  final paused=disabled.copy(budgetActive:false).copy(budgetActive:true);
  expect(paused.alertsEnabled,isFalse);
  expect(paused.alertPercent,75);
  expect(paused.deleted,isFalse);
 });

 test('M414 alert settings are strict without rejecting valid old backups',(){
  final normal=WaffraNamedBudget(id:'budget:1',name:'Food',budget:500);
  for(final invalid in [true,0,'false',<String,dynamic>{}]){
   final record={...normal.toJson(),'alertsEnabled':invalid};
   if(invalid==true)continue;
   expect(()=>WaffraNamedBudget.fromJson(record),throwsFormatException);
   final result=WaffraLegacyPreflight.inspect({
    'waffra_named_budgets_v1':jsonEncode([record]),
   });
   expect(result.canStage,isFalse);
  }
  expect(WaffraNamedBudget.fromJson(
   {...normal.toJson()}..remove('alertsEnabled')).alertsEnabled,isTrue);
 });

 test('M414 user-selected 50/75/80/95 thresholds are respected everywhere',(){
  final math=WaffraFinancialInsights.crossedBudgetThreshold;
  expect(math(previousSpent:490,spent:510,limit:1000,alertPercent:50,enabled:true),50);
  expect(math(previousSpent:749,spent:750,limit:1000,alertPercent:75,enabled:true),75);
  expect(math(previousSpent:799,spent:800,limit:1000,alertPercent:80,enabled:true),80);
  expect(math(previousSpent:949,spent:950,limit:1000,alertPercent:95,enabled:true),95);
  expect(math(previousSpent:951,spent:960,limit:1000,alertPercent:95,enabled:true),0);
  expect(math(previousSpent:950,spent:1000,limit:1000,alertPercent:95,enabled:true),100);
  expect(math(previousSpent:0,spent:1100,limit:1000,alertPercent:75,enabled:true),100);
  expect(math(previousSpent:0,spent:1100,limit:1000,alertPercent:75,enabled:false),0);
  expect(WaffraFinancialInsights.budgetThresholdVisible(
   spent:750,limit:1000,alertPercent:75,enabled:true),isTrue);
  expect(WaffraFinancialInsights.budgetThresholdVisible(
   spent:750,limit:1000,alertPercent:95,enabled:true),isFalse);
  expect(WaffraFinancialInsights.budgetThresholdVisible(
   spent:1000,limit:1000,alertPercent:50,enabled:false),isFalse);
  expect(WaffraFinancialInsights.budgetThresholdVisible(
   spent:1000,limit:1000,alertPercent:80,enabled:true),isTrue);
 });

 test('M414 SavingGoal factory and class close before SavingChallenge',(){
  final source=File('lib/main.dart').readAsStringSync();
  final model=source.split('class SavingGoal {').last
   .split('class SavingChallenge {').first;
  expect(model,contains("progressAlertPercent:j['progressAlertPercent'] as int? ??80);\n }\n}\n"));
 });

 test('M414 goal progress threshold does not affect money or recurrence',(){
  final old=SavingGoal(id:'g1',name:'Car',target:1000,saved:400);
  expect(old.progressAlertsEnabled,isFalse);
  final enabled=old.copy(progressAlertsEnabled:true,progressAlertPercent:60);
  final decoded=SavingGoal.fromJson(
   jsonDecode(jsonEncode(enabled.toJson())) as Map<String,dynamic>);
  expect(decoded.id,'g1');
  expect(decoded.target,1000);
  expect(decoded.saved,400);
  expect(decoded.progressAlertsEnabled,isTrue);
  expect(decoded.progressAlertPercent,60);
  expect(WaffraFinancialInsights.crossedBudgetThreshold(
   previousSpent:400,spent:650,limit:decoded.target,
   alertPercent:decoded.progressAlertPercent,
   enabled:decoded.progressAlertsEnabled),60);
  expect(WaffraFinancialInsights.crossedBudgetThreshold(
   previousSpent:400,spent:650,limit:0,alertPercent:60,enabled:true),0);
  expect(SavingGoal.fromJson({
   ...old.toJson()}..remove('progressAlertsEnabled')
     ..remove('progressAlertPercent')).progressAlertsEnabled,isFalse);
  expect(()=>SavingGoal.fromJson({
   ...old.toJson(),'progressAlertPercent':190}),throwsFormatException);
  expect(()=>SavingGoal.fromJson({
   ...old.toJson(),'progressAlertsEnabled':'false'}),throwsFormatException);
 });

 test('M414 budget and goal notification handling stays user-controlled',(){
  final source=File('lib/main.dart').readAsStringSync();
  final budgetAlert=source.split('Future<void> budgetAlert(').last
   .split('/// Draw the same category-colored donut').first;
  expect(budgetAlert,contains('b.budgetActive&&b.alertsEnabled'));
  expect(budgetAlert,contains('WaffraBudgetAlertOnce.claim('));
  expect(budgetAlert,contains('if(!newlyCrossed||!mounted)return;'));
  expect(budgetAlert,contains('showBudgetThreshold('));
  expect(budgetAlert,contains('تنبيه الميزانية'));
  expect(budgetAlert,isNot(contains('تنبيه ميزانية القسم')));
  final smart=source.split('final warnings=namedBudgets.where(').last
   .split('return Card(').first;
  expect(smart,contains('reachedBudgetThreshold('));
  expect(smart,contains('alertPercent:b.alertPercent'));
  expect(smart,contains('b.budgetActive&&b.alertsEnabled'));
  expect(smart,isNot(contains('>=80')));
  expect(source,contains('showGoalProgress('));
  final reminders=File('lib/waffra_reminders.dart').readAsStringSync();
  expect(reminders,contains('if(!await alreadyPermitted())return;'));
  expect(reminders,contains('showBudgetThreshold('));
  expect(reminders,contains('showGoalProgress('));
  expect(reminders,isNot(contains('Your budget balance is')));
 });

 testWidgets('M414 turning a budget alert off hides its percent picker',
  (tester)async{
   var enabled=true;
   var percent=80;
   await tester.pumpWidget(MaterialApp(home:Scaffold(
    body:StatefulBuilder(builder:(context,update)=>waffraBudgetAlertControls(
     enabled:enabled,percent:percent,english:false,
     onEnabled:(value)=>update(()=>enabled=value),
     onPercent:(value)=>update(()=>percent=value))))));
   expect(find.byKey(const Key('waffra-budget-alert-toggle')),findsOneWidget);
   expect(find.byKey(const ValueKey('waffra-budget-alert-percent-80')),
    findsOneWidget);
   await tester.tap(find.byKey(const Key('waffra-budget-alert-toggle')));
   await tester.pumpAndSettle();
   expect(enabled,isFalse);
   expect(find.byKey(const ValueKey('waffra-budget-alert-percent-80')),
    findsNothing);
   await tester.tap(find.byKey(const Key('waffra-budget-alert-toggle')));
   await tester.pumpAndSettle();
   expect(enabled,isTrue);
   expect(percent,80);
 });

 testWidgets('M414 goal progress alerts are separate and optional',
  (tester)async{
   var enabled=false;
   await tester.pumpWidget(MaterialApp(home:Scaffold(
    body:StatefulBuilder(builder:(context,update)=>waffraBudgetAlertControls(
     enabled:enabled,percent:75,english:false,goal:true,
     onEnabled:(value)=>update(()=>enabled=value),
     onPercent:(_){},
    )))));
   expect(find.byKey(const Key('waffra-goal-alert-toggle')),findsOneWidget);
   expect(find.byKey(const ValueKey('waffra-goal-alert-percent-75')),
    findsNothing);
   await tester.tap(find.byKey(const Key('waffra-goal-alert-toggle')));
   await tester.pumpAndSettle();
   expect(enabled,isTrue);
   expect(find.byKey(const ValueKey('waffra-goal-alert-percent-75')),
    findsOneWidget);
 });
}

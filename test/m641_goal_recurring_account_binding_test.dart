
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_goal_recurring_account_picker.dart';
import 'package:waffra/waffra_saudi_financial_providers.dart';

void main(){
 test('M641 goal account ID survives encrypted snapshot JSON and edits',(){
  final goal=SavingGoal(id:'g1',name:'سيارة',target:10000,saved:550,
   accountId:'verified-rajhi-current');
  expect(goal.toJson()['accountId'],'verified-rajhi-current');
  expect(SavingGoal.fromJson(goal.toJson()).accountId,
   'verified-rajhi-current');
  expect(goal.copy(name:'سيارة جديدة').accountId,
   'verified-rajhi-current');
  expect(SavingGoal.fromJson({
   'id':'old','name':'legacy','target':1000,'saved':150,
  }).accountId,isNull,reason:'Never invent an account for historical goals');
  for(final invalid in [42,'',' ',List.filled(129,'a').join()]){
   expect(()=>SavingGoal.fromJson({
    'id':'bad','name':'Corrupt','target':1000,'saved':0,
    'accountId':invalid,
   }),throwsFormatException,
    reason:'Invalid stored account identity must fail closed');
  }
 });

 test('M641 linked due preserves stable account and original goal identity',(){
  final bill=RecurringBill(id:'due',title:'استحقاق سيارة',
   category:'المواصلات',amount:10000,income:false,day:12,
   linkedGoalId:'g1',accountId:'verified-rajhi-current');
  expect(RecurringBill.fromJson(bill.toJson()).accountId,
   'verified-rajhi-current');
  expect(bill.copy(active:false).accountId,'verified-rajhi-current');
  final actions=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(actions,contains('accountId:updated.accountId'));
  expect(actions,contains('accountId:linkedAccount'));
  expect(actions,contains('WaffraRecurringPolicy.toHalalas(goals[i].saved)'));
  expect(actions,contains('WaffraRecurringPolicy.toHalalas(updated.saved)'));
  expect(actions,contains('مبلغ الادخار اتغير أثناء التعديل'));
  expect(actions,contains('WaffraRecurringPolicy.entryId(old.id,originalDue)'));
  expect(actions,contains("entry.id==settledKey&&entry.sourceType=='goal_due'"));
  expect(actions,contains('||alreadySettled?'));


  final writer=File('lib/storage/waffra_verified_goal_due_snapshot_writer.dart')
   .readAsStringSync();
  expect(writer,contains("recurring['accountId']!=goalAccountId"));
  expect(writer,contains('selectedAccountId!=goalAccountId'));
 });

 test('M641 zero-account recurring dialog opens; fund and due never double post',(){
  final app=File('lib/main.dart').readAsStringSync();
  final start=app.indexOf(' Future<void> recurringDialog(');
  final end=app.indexOf(' DateTime nextRecurringDue(',start);
  expect(start,greaterThan(0));expect(end,greaterThan(start));
  final editor=app.substring(start,end);
  expect(editor,isNot(contains('if(liveAccounts.isEmpty)')));
  expect(editor,contains('WaffraGoalRecurringAccountPicker('));
  expect(editor,contains('_m641CreateGoalRecurringAccount(provider)'));
  // First account creation advances the finance generation; next save must
  // use a refreshed verified baseline, not the witness from before the form.
  final helperStart=app.indexOf(' Future<WaffraAccountBalance?> _m641CreateGoalRecurringAccount(');
  final helperEnd=app.indexOf(' /// Release an earmark back to spendable cash.',helperStart);
  expect(helperStart,greaterThan(0));
  final helper=app.substring(helperStart,helperEnd);
  expect(helper,contains('await api.balances();'));
  expect(helper,contains('await api.createTypedAccountWithIdentity('));
  expect(helper,contains('await _refreshFromVerifiedFinance();'));
  expect(helper,contains('if(!mounted||!ready||_financeLoadFailure!=null)'));

  expect(editor,contains('selectedRecurringAccount!=null'));
  expect(editor,contains("if(initial?.linkedGoalId!=null)"));
  expect(editor,contains("'حساب الهدف (التعديل من الأهداف)'"));
  expect(editor,contains("selectedRecurringAccount=linked.single.accountId;"));
  final funding=app.substring(app.indexOf(' Future<void> fundGoal('),
   app.indexOf(' Future<void> deletedGoalsDialog('));
  expect(funding,contains('sourceAccountId:funding.sourceAccountId'));
  expect(funding,contains('fundVerifiedGoal('));
  expect(funding,contains('if(mounted)await _refreshFromVerifiedFinance();'));
  expect(funding,contains('if(mounted)await _loadFinanceSafely();'));
  // A verified success refresh must never re-enter cold Home/SMS startup.
  expect(funding,isNot(contains("sourceAccountId:chosenSource=='none'")));
  expect(funding,contains('final available=source.single.balanceMinor/100;'));
  expect(funding,isNot(contains('final available=waffraAvailableCash(entries,goals);')),
   reason:'Fresh account opening balance must drive savings warning');
  expect(app,contains("goalWalletPaidMinor:goalPreview.fromGoalMinor"));
  final sql=File('lib/storage/waffra_verified_goal_funding_writer.dart')
   .readAsStringSync();
  expect(sql,contains('attributeGoalMovement('));
  expect(sql,contains('await snapshot.commit('));
  final module=File('lib/storage/waffra_fresh_finance_modules_repository.dart')
   .readAsStringSync();
  expect(module,contains('Savings goal requires an active verified SAR account.'));
 });

 test('M641 local/digital banks and digital wallets remain distinct',(){
  expect(WaffraSaudiFinancialProviders.byId('rajhi')?.category,
   WaffraSaudiFinancialProviders.local);
  expect(WaffraSaudiFinancialProviders.byId('d360')?.category,
   WaffraSaudiFinancialProviders.digital);
  expect(WaffraSaudiFinancialProviders.byId('barq')?.category,
   WaffraSaudiFinancialProviders.wallet);
 });

 testWidgets('M641 empty recurring/goal selector offers create-account path',
  (tester)async{
   String? confirmed;
   var invoked=0;
   await tester.pumpWidget(MaterialApp(home:Scaffold(
    body:SingleChildScrollView(child:WaffraGoalRecurringAccountPicker(
     accounts:const <WaffraAccountBalance>[],
     idPrefix:'m641-first',onChanged:(id)=>confirmed=id,
     onError:(message)=>fail('Unexpected account creation error: $message'),
     onCreateAccount:(group)async{
      invoked++;
      return const WaffraAccountBalance(
       'new-account','مصرف الراجحي - الجاري','bank',0,false,
       providerId:'rajhi',subtype:'current');
     },
    )),
   )));
   await tester.pumpAndSettle();
   expect(find.byKey(const Key('m641-first-add-account')),findsOneWidget);
   expect(find.text('إضافة حساب'),findsOneWidget);
   await tester.tap(find.byKey(const Key('m641-first-add-account')));
   await tester.pumpAndSettle();
   expect(invoked,1);
   expect(confirmed,'new-account');
   expect(find.text('مصرف الراجحي'),findsOneWidget);
   expect(find.text('إضافة حساب تابع'),findsOneWidget);
  });
}

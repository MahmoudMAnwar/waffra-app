import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_transaction_form.dart';
import 'package:waffra/waffra_new_account_dialog.dart';
import 'package:waffra/waffra_saudi_financial_providers.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';

WaffraNewAccountDraft draft(String kind,String provider,int minor)=>
 WaffraNewAccountDraft(name:'حساب تابع',kind:kind,
  providerId:provider,subtype:kind=='wallet'?'digital':'current',
  openingMinor:minor);

void main(){
 test('M942 every catalog bank and wallet matches ONLY its verified parent',(){
  for(final provider in WaffraSaudiFinancialProviders.all){
   final kind=provider.category==WaffraSaudiFinancialProviders.wallet?
    'wallet':'bank';
   final candidate=draft(kind,provider.id,502525);
   expect(waffraProviderForAccountGroup(provider.groupId)?.id,provider.id);
   expect(waffraNewAccountMatchesGroup(provider.groupId,candidate),isTrue);
   expect(WaffraAccountDetailsSchema.valid(kind:kind,providerId:provider.id,
    subtype:kind=='bank'?'current':'digital'),isTrue,
    reason:'SQLCipher provider CHECK must accept every offered catalog institution');
   final wrong=kind=='wallet'?'bank':'wallet';
   expect(waffraNewAccountMatchesGroup(provider.groupId,
    draft(wrong,provider.id,502525)),isFalse);
   for(final other in WaffraSaudiFinancialProviders.all.where(
    (p)=>p.id!=provider.id)){
    expect(waffraNewAccountMatchesGroup(provider.groupId,
     draft(kind,other.id,502525)),isFalse);
   }
  }
  expect(waffraNewAccountMatchesGroup('bank:institution:other',
   draft('bank','other',500000)),isTrue);
  expect(waffraNewAccountMatchesGroup('wallet:institution:other',
   draft('wallet','other',500000)),isTrue);
  expect(waffraNewAccountMatchesGroup('bank:institution:other',
   draft('bank','rajhi',500000)),isFalse);
  expect(waffraNewAccountMatchesGroup('bank:account:legacy',
   draft('bank','rajhi',500000)),isFalse);
  expect(waffraNewAccountMatchesGroup('wallet:account:old',
   draft('wallet','barq',200000)),isFalse);
  expect(waffraNewAccountMatchesGroup('cash',
   WaffraNewAccountDraft(name:'نقدي',kind:'cash',openingMinor:0)),isTrue);
  expect(waffraNewAccountMatchesGroup(null,draft('bank','rajhi',500000)),isTrue);
 });

 test('M942 opening balance uses exact valid integer halalas',(){
  expect(waffraSarAmountMinor('٥٬٠٠٠٫٢٥',allowZero:true),500025);
  expect(waffraSarAmountMinor('2,000',allowZero:true),200000);
  expect(waffraSarAmountMinor('0',allowZero:true),0);
  expect(waffraSarAmountMinor('-2',allowZero:true),isNull);
  expect(waffraSarAmountMinor('1.234',allowZero:true),isNull);
 });

 testWidgets('M942 inline bank account dialog returns owner-confirmed opening',
  (tester)async{
  WaffraNewAccountDraft? created;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(
   builder:(context)=>FilledButton(onPressed:()async{
    created=await showDialog<WaffraNewAccountDraft>(
     context:context,builder:(ctx)=>const WaffraNewAccountDialog(
      english:true,suggestedProviderId:'rajhi'));
   },child:const Text('Create linked account'))))));
  await tester.tap(find.text('Create linked account'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('m470-new-account-label')),
   'Current account');
  await tester.enterText(find.byKey(const Key('m470-new-account-opening')),
   '5000.25');
  await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(
   find.byKey(const Key('m470-new-account-save'))).onPressed,isNotNull);
  await tester.tap(find.byKey(const Key('m470-new-account-save')));
  await tester.pumpAndSettle();
  expect(created?.kind,'bank');
  expect(created?.providerId,'rajhi');
  expect(created?.openingMinor,500025);
  expect(waffraNewAccountMatchesGroup('bank:institution:rajhi',created!),isTrue);
 });

 test('M942 all sources use same prewrite group guard and SQLCipher opening',(){
  final home=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final goal=File('lib/waffra_home_goal_actions.part.dart').readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
  final smsTransfer=File('lib/waffra_home_sms_transfer_review.part.dart')
   .readAsStringSync();
  final smsPicker=File('lib/waffra_home_verified_finance_pickers.part.dart')
   .readAsStringSync();
  final transfer=File('lib/waffra_home_verified_account_flows.part.dart')
   .readAsStringSync();
  final projected=File('lib/waffra_home_dashboard_analytics.part.dart')
   .readAsStringSync();
  final budget=File('lib/waffra_home_budget_cards.part.dart')
   .readAsStringSync();
  expect(home,contains('waffraNewAccountMatchesGroup(selectedParent,draft)'));
  expect(goal,contains('waffraNewAccountMatchesGroup(requestedGroupId,draft)'));
  expect(manager,contains('waffraNewAccountMatchesGroup(providerGroup,choice)'));
  expect(smsTransfer,contains('waffraNewAccountMatchesGroup(selectedGroup,choice)'));
  expect(smsTransfer,contains('waffraProviderForAccountGroup(selectedGroup)'));
  expect(smsTransfer,isNot(contains('rajhi|inma|snb|riyad|bilad|stc')));
  expect(smsPicker,contains('waffraNewAccountMatchesGroup(selectedGroup,draft)'));
  expect(smsPicker,contains('__m942_add_provider__'));
  expect(smsPicker,contains('__m942_add_child__'));
  expect(smsPicker,contains('await api.createTypedAccountWithIdentity('));
  expect(smsPicker,contains('generation:fresh.witness.generation'));
  expect(transfer,contains('_m641CreateGoalRecurringAccount('));
  expect(transfer,isNot(contains('await openVerifiedAccounts();\n       if(!mounted)return null;')));
  expect(projected,contains('final verifiedCash=_m942VerifiedAllAccountsBalance();'));
  expect(projected,contains("verifiedCash==null?'—'"));
  expect(budget,contains('final balance=_m942VerifiedAllAccountsBalance();'));
  expect(budget,contains("projection==null?'—'"));
  expect(projected,isNot(contains(
   'waffraAvailableCash(entries,goals)+nextIncome-nextExpenses')));
 });
}

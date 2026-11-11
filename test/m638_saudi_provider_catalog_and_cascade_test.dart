import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_recurring_account_groups.dart';
import 'package:waffra/waffra_saudi_financial_providers.dart';

void main(){
 test('M638 SAMA local/digital banks and named e-wallets are separate',(){
  final local=WaffraSaudiFinancialProviders.localBanks;
  final digital=WaffraSaudiFinancialProviders.digitalBanks;
  final wallets=WaffraSaudiFinancialProviders.digitalWallets;
  expect(local.length,11);
  expect(digital.map((p)=>p.labelAr),containsAll([
   'بنك إس تي سي','بنك فيجن','D360']));
  expect(wallets.map((p)=>p.labelAr),containsAll([
   'برق','إنجاز باي','الإنماء باي']));
  expect(local.map((p)=>p.id).toSet()
   .intersection(wallets.map((p)=>p.id).toSet()),isEmpty);
  expect(digital.map((p)=>p.id).toSet()
   .intersection(wallets.map((p)=>p.id).toSet()),isEmpty);
  expect(WaffraSaudiFinancialProviders.byId('stc')!.category,
   WaffraSaudiFinancialProviders.digital);
  expect(WaffraSaudiFinancialProviders.byId('d360')!.labelAr,'D360');
  expect(WaffraSaudiFinancialProviders.byId('inma')!.category,
   WaffraSaudiFinancialProviders.local);
  expect(WaffraSaudiFinancialProviders.byId('alinmapay')!.category,
   WaffraSaudiFinancialProviders.wallet);
  expect(WaffraSaudiFinancialProviders.categoryForGroup(
   'wallet:institution:barq'),WaffraSaudiFinancialProviders.wallet);
 });

 test('M638 provider catalog never fabricates accounts or mixes wallet and bank',(){
  const verified=[WaffraAccountBalance(
   'one','حساب برق الشخصي','wallet',4500,false,providerId:'barq')];
  final choices=WaffraRecurringAccountGroups.withBankProviderChoices(verified);
  final wallet=choices.singleWhere((p)=>p.id=='wallet:institution:barq');
  expect(wallet.category,WaffraSaudiFinancialProviders.wallet);
  expect(wallet.accounts.single.id,'one');
  expect(choices.singleWhere((p)=>p.id=='bank:institution:rajhi')
    .accounts,isEmpty);
  expect(choices.singleWhere((p)=>p.id=='bank:institution:d360')
    .accounts,isEmpty);
  expect(choices.where((p)=>p.accounts.isNotEmpty).length,1);
 });

 test('M638 income/expense/transfer gate parent type and dependent account',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('m638-home-manual-institution-type-'));
  expect(main,contains('m638-transfer-type-'));
  expect(main,contains('chosenManualProviderCategory=type;'));
  expect(main,contains('chosenManualAccount=null;'));
  expect(main,contains('chosenManualProviderCategory==null||'));
  expect(main,contains('groupCategory==null?null:(v)async{'));
  expect(main,contains('chosenManualProvider==null||'));
  expect(main,contains('onTap:selectedParentId==null?null:'));
  expect(main,contains('enabled:selectedParentId!=null'));
  expect(main,contains('key:const Key(\'waffra-entry-confirm-save\')'));
  expect(main,contains('!waffraCanAssignManualCategory(categories,income,selectedParentId,category)'));
  expect(main,isNot(contains('التحويل بين حساباتك لا يُحسب دخلًا ولا مصروفًا.')));
  expect(main,isNot(contains('لازم تضيف حسابين على الأقل قبل التحويل.')));
  // Stable salary/SMS account routing is still secured by owner confirmation.
  expect(main,contains('expectedAccountGeneration:reviewedAccount.generation'));
 });

 test('M638 new account selector stores wallet provider instead of another bank',(){
  final account=File('lib/waffra_new_account_dialog.dart').readAsStringSync();
  expect(account,contains('m638-bank-category-'));
  expect(account,contains('m470-new-account-provider'));
  expect(account,contains('WaffraSaudiFinancialProviders.wallet'));
  expect(account,contains("providerId:(kind=='bank'||kind=='wallet')?provider:'none'"));
  expect(account,contains("kind=selected?.category==WaffraSaudiFinancialProviders.wallet?'wallet':'bank'"));
 });
}

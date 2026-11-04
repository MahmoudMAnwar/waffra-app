import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const at='2026-11-04T13:00:00';
 WaffraAccountContextRepository get context=>
  WaffraAccountContextRepository(store:db,experimentalEnabled:true);
 WaffraAccountsRepository get accounts=>
  WaffraAccountsRepository(db:db,experimentalEnabled:true);
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m448-source');
  db=WaffraEncryptedStore.openAt(File(dir.path+'/store.sqlite'),
    key:'m448-only-disposable-verified-test-key');
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  await accounts.createAccount(id:'rajhi',name:'Al Rajhi',kind:'bank',
   openingMinor:200000,createdIso:at,userConfirmed:true);
  await accounts.createAccount(id:'cash',name:'Cash',kind:'cash',
   openingMinor:50000,createdIso:at,userConfirmed:true);
  await db.customStatement('INSERT INTO fresh_finance_goals '
   '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
   ['travel','Travel',200000,100000,'{}']);
  await db.customStatement('INSERT INTO fresh_finance_recurring '
   '(recurring_id,amount_minor,is_income,due_day,source_json) '
   'VALUES (?,?,?,?,?)',['internet',10000,0,1,'{}']);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('goal funding source debits bank once; goal creation never does',()async{
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor}, {'rajhi':200000,'cash':50000});
  await db.customStatement('INSERT INTO fresh_finance_goal_wallet_movements '
   '(movement_id,goal_id,kind,amount_minor,idempotency_key,occurred_at_iso) '
   'VALUES (?,?,?,?,?,?)',['fund-1','travel','fund',30000,'fund-key',at]);
  expect(await context.attributeGoalMovement(
   movementId:'fund-1',accountId:'rajhi',
   linkedIso:at,userConfirmed:true),true);
  expect(await context.attributeGoalMovement(
   movementId:'fund-1',accountId:'rajhi',
   linkedIso:at,userConfirmed:true),false);
  final progress=await context.goalProgress(
   goalId:'travel',selectedAccountId:'rajhi');
  expect(progress.totalSavedMinor,100000);
  expect(progress.selectedAccountNetMinor,30000);
  final latest={for(final a in await accounts.balances())a.id:a.balanceMinor};
  expect(latest['rajhi'],170000);
  expect(latest['cash'],50000);
  await expectLater(context.attributeGoalMovement(
   movementId:'fund-1',accountId:'cash',
   linkedIso:at,userConfirmed:true),throwsA(isA<StateError>()));
 });

 test('recurring saved default unaffected by one payment override and reminder',()async{
  await context.setRecurringDefault(
   recurringId:'internet',accountId:'rajhi',changedIso:at,
   userConfirmed:true);
  final once=WaffraAccountContextPolicy.recurringAccount(
   savedDefaultAccountId:await context.recurringDefault('internet'),
   chosenAccountId:'cash',
   change:WaffraRecurringAccountChange.thisPaymentOnly);
  expect(once.paymentAccountId,'cash');
  expect(once.nextDefaultAccountId,'rajhi');
  expect(await context.recurringDefault('internet'),'rajhi');
  await context.setRecurringDefault(
   recurringId:'internet',accountId:'cash',changedIso:at,
   userConfirmed:true);
  expect(await context.recurringDefault('internet'),'cash');
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor},
   {'rajhi':200000,'cash':50000});
 });

 test('only verified suffix chooses a bank; an unknown SMS stays unassigned',()async{
  await context.setVerifiedBankSuffix(
   accountId:'rajhi',lastFour:'1234',confirmedIso:at,userConfirmed:true);
  final recognized=await context.inferSmsAccount(
   const WaffraBankSmsFacts(kind:WaffraBankOperationKind.expense,
    sourceSuffix:'١٢٣٤'));
  expect(recognized.accountId,'rajhi');
  expect(recognized.confident,true);
  final unknown=await context.inferSmsAccount(
   const WaffraBankSmsFacts(kind:WaffraBankOperationKind.expense));
  expect(unknown.accountId,isNull);
  await expectLater(context.setVerifiedBankSuffix(
   accountId:'cash',lastFour:'9999',confirmedIso:at,userConfirmed:true),
    throwsA(isA<StateError>()));
  expect({for(final a in await accounts.balances())a.id:a.balanceMinor}, {'rajhi':200000,'cash':50000});
 });
}

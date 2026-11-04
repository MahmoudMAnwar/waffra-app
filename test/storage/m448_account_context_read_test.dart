import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main(){
 late Directory directory;
 late WaffraEncryptedStore db;
 const stamp='2026-11-04T12:00:00';
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('m448-context');
  db=WaffraEncryptedStore.openAt(File(directory.path+'/vault.sqlite'),
   key:'m448-disposable-only-sqlcipher-test-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
 });
 tearDown(()async{
  await db.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 Future<void> createAccount(String id) =>
  WaffraAccountsRepository(db:db,experimentalEnabled:true).createAccount(
   id:id,name:id,kind:'bank',openingMinor:100000,
   createdIso:stamp,userConfirmed:true);

 Future<void> transaction(String id,int minor,{bool income=false})async{
  await db.customStatement(
   'INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   [id,id,'Food',minor,income?1:0,stamp,'{}']);
 }

 test('all/unassigned budget and balance are independent of account header',()async{
  await createAccount('rajhi');await createAccount('cash');
  await transaction('bank-expense',20000);
  await transaction('cash-expense',10000);
  await transaction('unassigned-expense',5000);
  await transaction('unassigned-income',1000,income:true);
  final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  await accounts.linkEntry(entryId:'bank-expense',accountId:'rajhi',
   linkedIso:stamp,userConfirmed:true);
  await accounts.linkEntry(entryId:'cash-expense',accountId:'cash',
   linkedIso:stamp,userConfirmed:true);
  await db.customStatement('INSERT INTO fresh_finance_standalone_budgets '
   '(budget_id,name,monthly_limit_minor,created_at_iso,source_json) '
   'VALUES (?,?,?,?,?)',['food','Food',100000,stamp,'{}']);
  for(final (id,minor) in [
   ('bank-expense',20000),('cash-expense',10000),('unassigned-expense',5000)
  ]){
   await db.customStatement('INSERT INTO fresh_finance_standalone_allocations '
    '(allocation_id,budget_id,entry_id,amount_minor,assigned_at_iso,explicitly_confirmed) '
    'VALUES (?,?,?,?,?,1)',
    ['allocate-'+id,'food',id,minor,stamp]);
  }

  final context=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',selectedAccountId:'rajhi');
  expect(context.entries.length,4);
  expect(context.entries.where((e)=>e.accountId==null).length,2);
  expect(context.budgets.single.usage.globalSpentMinor,35000);
  expect(context.budgets.single.usage.selectedAccountSpentMinor,20000);
  expect(context.budgets.single.usage.reached(35),true);
  expect(context.budgets.single.usage.reached(36),false);

  final before={for(final a in await accounts.balances())a.id:a.balanceMinor};
  expect(before,{'rajhi':80000,'cash':90000});
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true);
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true);
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'cash',
   confirmedIso:stamp,userConfirmed:true),throwsA(isA<StateError>()));
  final after={for(final a in await accounts.balances())a.id:a.balanceMinor};
  expect(after,{'rajhi':75000,'cash':90000});
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
   .read<int>('n'),4);
 });
}

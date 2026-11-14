import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';

void main(){
 late Directory directory;
 late WaffraEncryptedStore store;
 const key='m942-only-disposable-SQLCipher-accounts-key';
 const at='2026-11-14T21:38:00Z';
 WaffraAccountsRepository accounts()=>WaffraAccountsRepository(
  db:store,experimentalEnabled:true);
 Future<int> count(String table)async=>(await store.customSelect(
  'SELECT COUNT(*) AS count FROM $table').getSingle()).read<int>('count');
 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m942-account-');
  store=WaffraEncryptedStore.openAt(
   File('${directory.path}/finance.sqlite'),key:key);
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAtomicFinanceSnapshot(
   store:store,experimentalEnabled:true).initializeEmpty();
  await WaffraAccountsSchema.install(store);
  await WaffraAccountDetailsSchema.install(store);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });
 test('M942 bank with two child openings: independent SAR, no income, cold SQLCipher persistence',()async{
  await accounts().createAccount(id:'rajhi-current',name:'الراجحي - الجاري',
   kind:'bank',openingMinor:500000,createdIso:at,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(store,
   accountId:'rajhi-current',kind:'bank',providerId:'rajhi',
   subtype:'current',confirmedIso:at);
  await accounts().createAccount(id:'rajhi-savings',name:'الراجحي - الادخار',
   kind:'bank',openingMinor:200000,createdIso:at,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(store,
   accountId:'rajhi-savings',kind:'bank',providerId:'rajhi',
   subtype:'savings',confirmedIso:at);
  var list=await accounts().balances();
  expect({for(final a in list)a.id:a.balanceMinor},
   {'rajhi-current':500000,'rajhi-savings':200000});
  expect(list.map((a)=>a.providerId).toSet(),{'rajhi'});
  expect(list.fold<int>(0,(n,a)=>n+a.balanceMinor),700000);
  expect(await count('fresh_finance_entries'),0,
   reason:'Opening balances are NOT income transactions');
  await store.close();
  store=WaffraEncryptedStore.openAt(
   File('${directory.path}/finance.sqlite'),key:key);
  await WaffraAccountsSchema.requireReady(store);
  list=await accounts().balances();
  expect({for(final a in list)a.id:a.balanceMinor},
   {'rajhi-current':500000,'rajhi-savings':200000});
  expect(list.fold<int>(0,(n,a)=>n+a.balanceMinor),700000);
  expect(await count('fresh_finance_entries'),0);
  expect(await accounts().transfer(
   id:'one',fromAccountId:'rajhi-current',toAccountId:'rajhi-savings',
   amountMinor:100000,occurredIso:at,userConfirmed:true),isTrue);
  list=await accounts().balances();
  expect({for(final a in list)a.id:a.balanceMinor},
   {'rajhi-current':400000,'rajhi-savings':300000});
  expect(list.fold<int>(0,(n,a)=>n+a.balanceMinor),700000);
  expect(await count('fresh_finance_entries'),0);
  expect(await count('fresh_finance_internal_transfers'),1);
 });
}

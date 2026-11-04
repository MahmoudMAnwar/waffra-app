import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const secret='m440-atomic-manual-account-tests-disposable-key';
 WaffraAtomicFinanceSnapshot snapshot()=>
  WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
 WaffraUnifiedFinanceWriter writer()=>WaffraUnifiedFinanceWriter(
  writerDirectory:dir,snapshot:snapshot(),experimentalEnabled:true);
 Map<String,Object?> income(String id,{bool credited=true})=>{
  'id':id,'title':'Manual salary','category':'راتب',
  'amount':50.00,'income':credited,'date':'2026-11-03T17:00:00',
  'receiptPath':null,'notes':'','sourceType':'manual',
 };
 Future<void> initialize()async{
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await snapshot().initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountsRepository(db:db,experimentalEnabled:true).createAccount(
   id:'bank',name:'Bank',kind:'bank',openingMinor:0,
   createdIso:'2026-11-03T15:00:00',userConfirmed:true);
 }
 Future<int> count(String table)async =>(await db.customSelect(
  'SELECT count(*) AS n FROM '+table).getSingle()).read<int>('n');
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m440-atomic');
  db=WaffraEncryptedStore.openAt(File(dir.path+'/money.sqlite'),key:secret);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });
 test('M440 account-linked manual income is one atomic ledger + link + snapshot commit',()async{
  await initialize();
  final initial=await snapshot().read();
  final saved=await writer().appendTransactions(
   records:[income('salary')],messageHashes:[null],
   userConfirmed:true,accountId:'bank',
   expectedAccountGeneration:initial.generation);
  expect(saved.saved,1);
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),1);
  expect((await snapshot().read()).generation,1);
  final balances=await WaffraAccountsRepository(db:db,experimentalEnabled:true).balances();
  expect(balances.single.balanceMinor,5000);
  expect(jsonDecode((await snapshot().read()).values['entries'] as String),isA<List>());
 });
 test('M440 non-existent account, stale source and unapproved save never post',()async{
  await initialize();
  await expectLater(writer().appendTransactions(records:[income('missing')],
   messageHashes:[null],userConfirmed:true,accountId:'absent',
   expectedAccountGeneration:0),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),0);
  final current=await snapshot().read();
  await snapshot().commit(expectedGeneration:current.generation,
   fullFinanceSnapshot:current.values);
  await expectLater(writer().appendTransactions(records:[income('stale')],
   messageHashes:[null],userConfirmed:true,accountId:'bank',
   expectedAccountGeneration:0),throwsA(isA<StateError>()));
  await expectLater(writer().appendTransactions(records:[income('unconfirmed')],
   messageHashes:[null],userConfirmed:false,accountId:'bank',
   expectedAccountGeneration:1),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),0);
  expect(await count('fresh_finance_account_entry_links'),0);
 });
 test('M440 existing bank SMS path never fabricates account links',()async{
  await initialize();
  final saved=await writer().appendTransactions(records:[income('sms-id')],
   messageHashes:[null],userConfirmed:true);
  expect(saved.saved,1);
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),0);
 });

 test('M440 confirmed SMS batch assigns each account atomically; duplicate hash never double-credits',()async{
  await initialize();
  await WaffraAccountsRepository(db:db,experimentalEnabled:true).createAccount(
   id:'cash',name:'Cash',kind:'cash',openingMinor:0,
   createdIso:'2026-11-03T15:01:00',userConfirmed:true);
  final first=income('salary-sms')..['sourceType']='bank_sms';
  final second=income('fuel-sms',credited:false)..['sourceType']='bank_sms';
  final saved=await writer().appendTransactions(
   records:[first,second],messageHashes:['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'],
   selectedAccountIds:['bank','cash'],userConfirmed:true,
   expectedAccountGeneration:(await snapshot().read()).generation);
  expect(saved.saved,2);
  expect(await count('fresh_finance_entries'),2);
  expect(await count('fresh_finance_account_entry_links'),2);
  final balances=await WaffraAccountsRepository(db:db,experimentalEnabled:true).balances();
  expect({for(final account in balances)account.id:account.balanceMinor},
   {'bank':5000,'cash':-5000});
  final duplicate=await writer().appendTransactions(
   records:[income('duplicate-sms')..['sourceType']='bank_sms'],
   messageHashes:['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'],selectedAccountIds:['bank'],
   userConfirmed:true,expectedAccountGeneration:(await snapshot().read()).generation);
  expect(duplicate.saved,0);
  expect(await count('fresh_finance_entries'),2);
  expect(await count('fresh_finance_account_entry_links'),2);
 });
 test('M440 recurring account allocation rejects stale revision and absent account',()async{
  await initialize();
  final recurring=income('recurring-rent',credited:false)
   ..['sourceType']='recurring';
  await expectLater(writer().appendTransactions(
   records:[recurring],messageHashes:[null],
   selectedAccountIds:['nonexistent'],userConfirmed:true,
   expectedAccountGeneration:0),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),0);
  await writer().appendTransactions(records:[recurring],
   messageHashes:[null],selectedAccountIds:['bank'],
   userConfirmed:true,expectedAccountGeneration:0);
  expect((await WaffraAccountsRepository(db:db,experimentalEnabled:true)
    .balances()).single.balanceMinor,-5000);
  await expectLater(writer().appendTransactions(
   records:[income('stale-recurrence')],messageHashes:[null],
   selectedAccountIds:['bank'],userConfirmed:true,
   expectedAccountGeneration:0),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),1);
 });
 test('M440 linked batch refuses misaligned account selections',()async{
  await initialize();
  await expectLater(writer().appendTransactions(
   records:[income('a'),income('b')],messageHashes:[null,null],
   selectedAccountIds:['bank'],userConfirmed:true,
   expectedAccountGeneration:0),throwsA(isA<ArgumentError>()));
  expect(await count('fresh_finance_entries'),0);
 });

 test('M440 account-link duplicate rollback preserves prior money',()async{
  await initialize();
  await writer().appendTransactions(records:[income('same')],
   messageHashes:[null],userConfirmed:true,accountId:'bank',
   expectedAccountGeneration:0);
  final latest=(await snapshot().read()).generation;
  await expectLater(writer().appendTransactions(records:[income('same')],
   messageHashes:[null],userConfirmed:true,accountId:'bank',
   expectedAccountGeneration:latest),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),1);
  expect((await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .balances()).single.balanceMinor,5000);
 });
}

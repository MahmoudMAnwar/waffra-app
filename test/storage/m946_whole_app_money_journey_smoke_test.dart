import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

/// M946: actual SQLCipher cross-feature smoke, not a source-text inspection.
/// Every run uses a new disposable encrypted vault with synthetic records.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory work;
 late File vault;
 late WaffraEncryptedStore db;
 const key='m946-disposable-sqlcipher-smoke-key-2026';
 WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(
  store:db,experimentalEnabled:true);
 WaffraUnifiedFinanceWriter writer()=>WaffraUnifiedFinanceWriter(
  writerDirectory:work,snapshot:snapshot(),experimentalEnabled:true);
 WaffraAccountsRepository accounts()=>WaffraAccountsRepository(
  db:db,experimentalEnabled:true);
 Future<int> count(String table)async{
  final row=await db.customSelect('SELECT count(*) AS n FROM '+table).getSingle();
  return row.read<int>('n');
 }
 Map<String,Object?> entry(String id,{required bool income,required double amount,
  String source='manual'})=><String,Object?>{
   'id':id,'title':'M946 synthetic $id','category':income?'الراتب':'طعام',
   'amount':amount,'income':income,'date':'2026-11-15T10:00:00.000',
   'sourceType':source,'notes':'','receiptPath':null,
  };
 setUp(()async{
  work=await Directory.systemTemp.createTemp('waffra-m946-all-features-');
  vault=File('${work.path}/finance.sqlite');
  db=WaffraEncryptedStore.openAt(vault,key:key);
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await snapshot().initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await accounts().createAccount(
   id:'bank',name:'Synthetic local bank',kind:'bank',openingMinor:100000,
   createdIso:'2026-11-15T08:00:00Z',userConfirmed:true);
  await accounts().createAccount(
   id:'wallet',name:'Synthetic digital wallet',kind:'cash',openingMinor:50000,
   createdIso:'2026-11-15T08:01:00Z',userConfirmed:true);
 });
 tearDown(()async{
  await db.close();
  if(await work.exists())await work.delete(recursive:true);
 });

 test('M946 account creation -> manual income/expense -> balance -> history '
  '-> cold reopen: no cross-account leak',()async{
  final original=await snapshot().read();
  final posted=await writer().appendTransactions(
   records:[
    entry('m946-salary',income:true,amount:250),
    entry('m946-groceries',income:false,amount:45),
   ],
   messageHashes:[null,null],selectedAccountIds:['bank','bank'],
   userConfirmed:true,expectedAccountGeneration:original.generation);
  expect(posted.saved,2);
  expect(await count('fresh_finance_entries'),2);
  expect(await count('fresh_finance_account_entry_links'),2);
  final before=await accounts().balances();
  expect(before.singleWhere((a)=>a.id=='bank').balanceMinor,120500);
  expect(before.singleWhere((a)=>a.id=='wallet').balanceMinor,50000);
  final month=await WaffraAccountContextRead.loadMonthEntries(
   store:db,monthIso:'2026-11',selectedAccountId:'bank');
  expect(month.map((e)=>e.id).toSet(),{'m946-salary','m946-groceries'});
  final wallet=await WaffraAccountContextRead.loadMonthEntries(
   store:db,monthIso:'2026-11',selectedAccountId:'wallet');
  expect(wallet,isEmpty);
  final canonical=(await snapshot().read()).values['entries'] as String;
  final rows=(jsonDecode(canonical) as List).cast<Map>();
  expect(rows.map((e)=>e['id']).toSet(),{'m946-salary','m946-groceries'});
  await db.close();
  db=WaffraEncryptedStore.openAt(vault,key:key);
  expect(await count('fresh_finance_entries'),2);
  expect(await count('fresh_finance_account_entry_links'),2);
  final reopened=await accounts().balances();
  expect(reopened.singleWhere((a)=>a.id=='bank').balanceMinor,120500);
  expect(reopened.singleWhere((a)=>a.id=='wallet').balanceMinor,50000);
  expect((await snapshot().read()).values['entries'],canonical);
 });

 test('M946 old unassigned finance stays visible but cannot silently '
  'credit a bank; duplicate manual ID cannot charge twice',()async{
  final s=await snapshot().read();
  await writer().appendTransactions(
   records:[entry('m946-old-income',income:true,amount:90)],
   messageHashes:[null],userConfirmed:true);
  final unknown=await WaffraAccountContextRead.unassignedSummary(store:db);
  expect(unknown.count,1);
  expect(unknown.netMinor,9000);
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),0);
  expect((await accounts().balances()).singleWhere(
   (a)=>a.id=='bank').balanceMinor,100000);
  final next=(await snapshot().read()).generation;
  await writer().appendTransactions(
   records:[entry('m946-current-expense',income:false,amount:15)],
   messageHashes:[null],selectedAccountIds:['bank'],
   userConfirmed:true,expectedAccountGeneration:next);
  expect(await count('fresh_finance_entries'),2);
  expect((await WaffraAccountContextRead.unassignedSummary(store:db)).count,1);
  expect((await accounts().balances()).singleWhere(
   (a)=>a.id=='bank').balanceMinor,98500);
  final locked=await snapshot().read();
  await expectLater(writer().appendTransactions(
   records:[entry('m946-current-expense',income:false,amount:15)],
   messageHashes:[null],selectedAccountIds:['bank'],
   userConfirmed:true,expectedAccountGeneration:locked.generation),
   throwsA(isA<StateError>()));
  expect(await count('fresh_finance_entries'),2);
  expect((await snapshot().read()).digest,locked.digest);
  expect((await accounts().balances()).singleWhere(
   (a)=>a.id=='bank').balanceMinor,98500);
  expect(s.generation,0);
 });

 test('M946 reviewed SMS hash is idempotent and never double-posts '
  'into linked bank or wallet',()async{
  const hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final first=await writer().appendTransactions(
   records:[entry('m946-reviewed-sms',income:true,amount:75,
    source:'bank_sms')],
   messageHashes:[hash],selectedAccountIds:['wallet'],
   userConfirmed:true,expectedAccountGeneration:(await snapshot().read()).generation);
  expect(first.saved,1);
  final after=await snapshot().read();
  final repeated=await writer().appendTransactions(
   records:[entry('m946-sms-duplicate',income:true,amount:75,
    source:'bank_sms')],
   messageHashes:[hash],selectedAccountIds:['wallet'],
   userConfirmed:true,expectedAccountGeneration:after.generation);
  expect(repeated.saved,0);
  expect(await count('fresh_finance_entries'),1);
  expect(await count('fresh_finance_account_entry_links'),1);
  final balances=await accounts().balances();
  expect(balances.singleWhere((a)=>a.id=='wallet').balanceMinor,57500);
  expect(balances.singleWhere((a)=>a.id=='bank').balanceMinor,100000);
 });
}

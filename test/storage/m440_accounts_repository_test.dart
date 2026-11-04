import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

void main() {
 late Directory directory;
 late WaffraEncryptedStore db;
 const secret='m440-test-only-sqlcipher-disposable-encryption-key';

 WaffraAccountsRepository repo({bool enabled=true}) =>
   WaffraAccountsRepository(db:db,experimentalEnabled:enabled);
 Future<void> bootstrap()async{
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
 }
 Future<void> create(String id,int opening)=>repo().createAccount(
  id:id,name:id,kind:'bank',openingMinor:opening,
  createdIso:'2026-11-03T13:00:00',userConfirmed:true);
 Future<int> count(String table)async=>(await db.customSelect(
  'SELECT count(*) AS n FROM $table').getSingle()).read<int>('n');

 setUp(()async{
  directory=await Directory.systemTemp.createTemp('waffra-m440');
  db=WaffraEncryptedStore.openAt(
   File(directory.path+'/m440.sqlite'),key:secret);
 });
 tearDown(()async{
  await db.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 test('M440 schema requires existing SQLCipher finance domain and starts empty',()async{
  await expectLater(WaffraAccountsSchema.install(db),throwsA(isA<StateError>()));
  await bootstrap();
  for(final table in WaffraAccountsSchema.tables)expect(await count(table),0);
  await expectLater(repo(enabled:false).balances(),throwsA(isA<StateError>()));
 });

 test('M440 internal SAR transfer conserves total and is never income/expense',()async{
  await bootstrap();await create('bank',500000);await create('cash',200000);
  expect(await repo().transfer(id:'move1',fromAccountId:'bank',toAccountId:'cash',
   amountMinor:100000,occurredIso:'2026-11-03T14:00:00',userConfirmed:true),isTrue);
  final accounts={for(final a in await repo().balances())a.id:a.balanceMinor};
  expect(accounts,{'bank':400000,'cash':300000});
  expect(accounts.values.fold<int>(0,(a,b)=>a+b),700000);
  expect(await count('fresh_finance_entries'),0);
  expect(await count('fresh_finance_internal_transfers'),1);
 });

 test('M440 idempotent replay and conflict detection prevent double debit',()async{
  await bootstrap();await create('a',1000);await create('b',0);
  Future<bool> transfer(int amount,{bool approved=true})=>repo().transfer(
   id:'same',fromAccountId:'a',toAccountId:'b',amountMinor:amount,
   occurredIso:'2026-11-03T14:00:00',userConfirmed:approved);
  await expectLater(transfer(100,approved:false),throwsA(isA<StateError>()));
  expect(await transfer(100),isTrue);
  expect(await transfer(100),isFalse);
  await expectLater(transfer(200),throwsA(isA<StateError>()));
  expect(await count('fresh_finance_internal_transfers'),1);
  expect({for(final a in await repo().balances())a.id:a.balanceMinor},
   {'a':900,'b':100});
 });

 test('M440 same or missing destination must not change balance',()async{
  await bootstrap();await create('cash',1000);
  await expectLater(repo().transfer(id:'same',fromAccountId:'cash',
   toAccountId:'cash',amountMinor:100,
   occurredIso:'2026-11-03T14:00:00',userConfirmed:true),
   throwsA(isA<ArgumentError>()));
  await expectLater(repo().transfer(id:'missing',fromAccountId:'cash',
   toAccountId:'absent',amountMinor:100,
   occurredIso:'2026-11-03T14:00:00',userConfirmed:true),
   throwsA(isA<StateError>()));
  expect(await count('fresh_finance_internal_transfers'),0);
 });

 test('M440 historical records are linked only by approved verified migration',()async{
  await bootstrap();await create('cash',0);
  final source=jsonEncode({'id':'historical','amount':75.0,'income':true});
  await db.customStatement('INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   ['historical','Old salary','Income',7500,1,'2026-10-01T13:00:00',source]);
  Future<int> link(bool proof)=>repo().linkHistoricalEntries(
   accountId:'cash',linkedIso:'2026-11-03T15:00:00',
   userConfirmed:true,verifiedMigration:proof);
  await expectLater(link(false),throwsA(isA<StateError>()));
  expect(await link(true),1);
  expect(await link(true),0);
  expect((await repo().balances()).single.balanceMinor,7500);
  expect((await db.customSelect(
   "SELECT source_json FROM fresh_finance_entries WHERE entry_id='historical'")
   .getSingle()).read<String>('source_json'),source);
 });

 test('M440 account transfer remains encrypted on database reopen',()async{
  await bootstrap();await create('a',500);await create('b',0);
  await repo().transfer(id:'persisted',fromAccountId:'a',toAccountId:'b',
   amountMinor:100,occurredIso:'2026-11-03T15:00:00',userConfirmed:true);
  await db.close();
  db=WaffraEncryptedStore.openAt(
   File(directory.path+'/m440.sqlite'),key:secret);
  await WaffraAccountsSchema.requireReady(db);
  expect({for(final a in await repo().balances())a.id:a.balanceMinor},
   {'a':400,'b':100});
 });

 test('M440 historical association rejects a second opening balance',()async{
  await bootstrap();await create('already-current',7500);
  await expectLater(repo().linkHistoricalEntries(
   accountId:'already-current',linkedIso:'2026-11-03T15:00:00',
   userConfirmed:true,verifiedMigration:true),throwsA(isA<StateError>()));
  expect((await repo().balances()).single.balanceMinor,7500);
 });

 test('M440 settled goal wallet expense debits only actual cash portion',()async{
  await bootstrap();await create('cash',100000);
  await db.customStatement(
   'INSERT INTO fresh_finance_goals '
   '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
   ['g','Rent goal',20000,0,'{}']);
  await db.customStatement(
   'INSERT INTO fresh_finance_recurring '
   '(recurring_id,amount_minor,is_income,due_day,source_json) VALUES (?,?,?,?,?)',
   ['r',20000,0,1,'{}']);
  await db.customStatement(
   'INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,occurred_iso,'
   'receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   ['due','Rent','Rent',20000,0,'2026-11-03T15:00:00','{}']);
  await db.customStatement(
   'INSERT INTO fresh_finance_goal_due_settlements '
   '(due_key,goal_id,recurring_id,entry_id,amount_minor,goal_wallet_minor,'
   'current_cash_minor,confirmed_at_iso) VALUES (?,?,?,?,?,?,?,?)',
   ['due-2026-11','g','r','due',20000,15000,5000,'2026-11-03T15:00:00']);
  await repo().linkEntry(entryId:'due',accountId:'cash',
   linkedIso:'2026-11-03T15:00:00',userConfirmed:true);
  expect((await repo().balances()).single.balanceMinor,95000);
  expect(await count('fresh_finance_internal_transfers'),0);
 });

 test('M440 account archive refuses nonzero balance',()async{
  await bootstrap();await create('savings',100);
  await expectLater(repo().archiveEmptyAccount(id:'savings',userConfirmed:true),
   throwsA(isA<StateError>()));
  expect((await repo().balances()).single.archived,isFalse);
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
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


 test('goal wallet total remains independent of account-sourced contribution',()async{
  await createAccount('rajhi');
  await createAccount('cash');
  await db.customStatement('INSERT INTO fresh_finance_goals '
   '(goal_id,name,target_minor,saved_minor,source_json) '
   'VALUES (?,?,?,?,?)',['travel','Travel',100000,50000,'{}']);
  await db.customStatement('INSERT INTO fresh_finance_goal_wallet_movements '
   '(movement_id,goal_id,kind,amount_minor,idempotency_key,occurred_at_iso) '
   'VALUES (?,?,?,?,?,?)',
   ['source-1','travel','fund',30000,'source-once',stamp]);
  final attribution=WaffraAccountContextRepository(
   store:db,experimentalEnabled:true);
  expect(await attribution.attributeGoalMovement(
   movementId:'source-1',accountId:'rajhi',
   linkedIso:stamp,userConfirmed:true),true);
  final rajhi=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',selectedAccountId:'rajhi');
  final cash=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',selectedAccountId:'cash');
  expect(rajhi.goals.single.totalSavedMinor,50000);
  expect(rajhi.goals.single.selectedAccountNetMinor,30000);
  expect(cash.goals.single.totalSavedMinor,50000);
  expect(cash.goals.single.selectedAccountNetMinor,0);
  expect({for(final a in await WaffraAccountsRepository(
    db:db,experimentalEnabled:true).balances()) a.id:a.balanceMinor},
    {'rajhi':70000,'cash':100000});
 });

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
  // A nonzero opening may already include old transactions; reject without
  // a separate explicit attestation, leaving balances and links unchanged.
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true),throwsA(isA<StateError>()));
  expect((await db.customSelect(
   "SELECT count(*) AS n FROM fresh_finance_account_entry_links "
   "WHERE entry_id='unassigned-expense'").getSingle()).read<int>('n'),0);
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true,openingExcludesHistory:true);
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true,openingExcludesHistory:true);
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'unassigned-expense',accountId:'cash',
   confirmedIso:stamp,userConfirmed:true,openingExcludesHistory:true),
   throwsA(isA<StateError>()));
  final after={for(final a in await accounts.balances())a.id:a.balanceMinor};
  expect(after,{'rajhi':75000,'cash':90000});
  expect((await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
   .read<int>('n'),4);
 });

 test('M686 SQLCipher accounting month uses indexable date predicate',()async{
  // Keep the month filter inside SQLite rather than an OR expression that
  // can force a full encrypted-history scan for every summary refresh.
  final source=File('lib/storage/waffra_account_context_read.dart')
   .readAsStringSync();
  expect(source,contains(
   "summaryOnly ? 'WHERE e.occurred_iso>=? AND e.occurred_iso<?' : ''"));
  expect(source,isNot(contains('WHERE (?=0 OR')));
  // Initialize verified account/context projections in this isolated vault.
  // These rows remain unassigned and must not debit the sample bank account.
  await createAccount('rajhi');
  await transaction('month-november',3000);
  await db.customStatement(
   'INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   ['month-october','October','Food',2500,0,
    '2026-10-04T12:00:00','{}']);
  final month=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',summaryOnly:true);
  expect(month.entries.map((e)=>e.id).toList(),['month-november']);
  final history=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',summaryOnly:false);
  expect(history.entries.map((e)=>e.id).toSet(),
   {'month-october','month-november'});
  final unassigned=await WaffraAccountContextRead.loadUnassignedEntries(
   store:db,limit:1,offset:0);
  expect(unassigned.length,1);
  expect((await WaffraAccountContextRead.unassignedSummary(store:db)).count,2);
 });

 test('M684 summary reads only chosen month without changing full-history API',()async{
  await createAccount('rajhi');
  await transaction('nov-current',3000);
  await db.customStatement(
   'INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   ['oct-legacy','October','Food',2000,0,'2026-10-08T12:00:00','{}']);
  // Legacy callers intentionally retain all authenticated entries.
  final full=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11');
  expect(full.entries.map((e)=>e.id).toSet(),{'nov-current','oct-legacy'});
  // The Account Context screen must NOT read older ledger rows to render
  // November budget totals; it opens a separate all-time unassigned queue.
  final month=await WaffraAccountContextRead.load(
   store:db,monthIso:'2026-11',summaryOnly:true);
  expect(month.entries.map((e)=>e.id).toList(),['nov-current']);
  final november=await WaffraAccountContextRead.loadMonthEntries(
   store:db,monthIso:'2026-11',limit:50);
  expect(november.map((e)=>e.id).toList(),['nov-current']);
  final october=await WaffraAccountContextRead.loadMonthEntries(
   store:db,monthIso:'2026-10',limit:50);
  expect(october.map((e)=>e.id).toList(),['oct-legacy']);
  final unlinked=await WaffraAccountContextRead.unassignedSummary(store:db);
  expect(unlinked.count,2);
  expect(unlinked.netMinor,-5000);
  expect((await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances()).single.balanceMinor,100000);
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:db,entryId:'oct-legacy',accountId:'rajhi',
   confirmedIso:stamp,userConfirmed:true,openingExcludesHistory:true);
  expect(await WaffraAccountContextRead.loadAccountEntryIds(
   store:db,accountId:'rajhi'),{'oct-legacy'});
  expect(await WaffraAccountContextRead.loadAccountEntryIds(
   store:db,accountId:'unknown'),isEmpty);
 });
}

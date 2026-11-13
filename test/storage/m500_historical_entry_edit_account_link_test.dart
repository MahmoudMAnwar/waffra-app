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
 late WaffraEncryptedStore store;
 late WaffraAccountsRepository accounts;
 late WaffraAccountContextRepository context;
 const now='2026-11-06T12:00:00';

 setUp(()async{
  directory=await Directory.systemTemp.createTemp('m500-old-entry-');
  store=WaffraEncryptedStore.openAt(File('${directory.path}/vault.sqlite'),
   key:'m500-disposable-test-only-sqlcipher-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:store,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(store);
  accounts=WaffraAccountsRepository(db:store,experimentalEnabled:true);
  context=WaffraAccountContextRepository(
   store:store,experimentalEnabled:true);
  await accounts.createAccount(id:'rajhi',name:'Current',kind:'bank',
   openingMinor:100000,createdIso:now,userConfirmed:true);
  await accounts.createAccount(id:'wallet',name:'Savings',kind:'wallet',
   openingMinor:0,createdIso:now,userConfirmed:true);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 Future<void> insertHistorical(String id,{bool income=false})async{
  await store.customStatement(
   'INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
   [id,'Old retained transaction','Household',12750,
    income?1:0,now,'{"source":"legacy-import","retained":true}']);
 }

 test('M500 missing legacy-only ID never becomes a fake verified accountless row',()async{
  final old=await context.readExistingEntryAccount(entryId:'legacy-not-migrated');
  expect(old.exists,false);
  expect(old.accountId,isNull);
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:store,entryId:'legacy-not-migrated',accountId:'rajhi',
   confirmedIso:now,userConfirmed:true),throwsA(isA<StateError>()));
 });

 test('M500 historical expense links once; original money, metadata and ID preserved',()async{
  await insertHistorical('old-2018-expense');
  final before=await context.readExistingEntryAccount(entryId:'old-2018-expense');
  expect(before.exists,true);
  expect(before.accountId,isNull);
  final initialBalance=(await accounts.balances()).firstWhere(
   (a)=>a.id=='rajhi').balanceMinor;
  expect(initialBalance,100000);

  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:store,entryId:'old-2018-expense',accountId:'rajhi',
   confirmedIso:now,userConfirmed:true,openingExcludesHistory:true);
  await WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:store,entryId:'old-2018-expense',accountId:'rajhi',
   confirmedIso:now,userConfirmed:true,openingExcludesHistory:true);
  final linked=await context.readExistingEntryAccount(
   entryId:'old-2018-expense');
  expect(linked.exists,true);
  expect(linked.accountId,'rajhi');
  final balance=(await accounts.balances()).firstWhere(
   (a)=>a.id=='rajhi').balanceMinor;
  expect(balance,87250);

  final entry=await store.customSelect(
   'SELECT entry_id, amount_minor, is_income, source_json '
   'FROM fresh_finance_entries WHERE entry_id=\'old-2018-expense\'',
  ).get(); // Assert row contents via the sole retained fixture.
  expect(entry.length,1);
  expect(entry.single.read<String>('entry_id'),'old-2018-expense');
  expect(entry.single.read<int>('amount_minor'),12750);
  expect(entry.single.read<int>('is_income'),0);
  expect(entry.single.read<String>('source_json'),
   '{"source":"legacy-import","retained":true}');
  final links=await store.customSelect(
   'SELECT account_id FROM fresh_finance_account_entry_links').get();
  expect(links.length,1);
  expect(links.single.read<String>('account_id'),'rajhi');
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:store,entryId:'old-2018-expense',accountId:'wallet',
   confirmedIso:now,userConfirmed:true),throwsA(isA<StateError>()));
  expect((await accounts.balances()).firstWhere(
   (a)=>a.id=='rajhi').balanceMinor,87250);
 });

 test('M500 explicit confirmation required; failed/canceled link preserves balance',()async{
  await insertHistorical('unassigned-income',income:true);
  await expectLater(WaffraAccountContextRead.attachPreviouslyUnassigned(
   store:store,entryId:'unassigned-income',accountId:'rajhi',
   confirmedIso:now,userConfirmed:false),throwsA(isA<StateError>()));
  expect((await context.readExistingEntryAccount(
   entryId:'unassigned-income')).accountId,isNull);
  expect((await accounts.balances()).firstWhere(
   (a)=>a.id=='rajhi').balanceMinor,100000);
 });
}

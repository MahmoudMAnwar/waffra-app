import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_account_details_schema.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 const key='m942-test-disposable-sqlcipher-legacy-details-v1';
 const date='2026-11-14T21:42:00Z';
 Future<int> count(String table)async=>(await db.customSelect(
  'SELECT COUNT(*) AS n FROM $table').getSingle()).read<int>('n');
 Future<int> revision()async=>(await db.customSelect(
  "SELECT version FROM fresh_finance_account_details_revision "
  "WHERE slot='account_details'").getSingle()).read<int>('version');
 Future<void> seedV1()async{
  await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .createAccount(id:'old-rajhi',name:'الراجحي - جاري',kind:'bank',
    openingMinor:420050,createdIso:date,userConfirmed:true);
  await db.customStatement('''
CREATE TABLE fresh_finance_account_details(
 account_id TEXT PRIMARY KEY NOT NULL
 REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 provider_id TEXT NOT NULL CHECK(provider_id IN
 ('rajhi','inma','snb','riyad','bilad','stc','other','none')),
 subtype TEXT NOT NULL CHECK(subtype IN
 ('current','savings','investment','deposit','digital','prepaid','cash','other')),
 confirmed_iso TEXT NOT NULL
)''');
  await db.customStatement('''
CREATE TABLE fresh_finance_account_details_revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='account_details'),
 version INTEGER NOT NULL CHECK(version=1)
)''');
  await db.customStatement(
   "INSERT INTO fresh_finance_account_details_revision(slot,version) "
   "VALUES('account_details',1)");
  await db.customStatement(
   "INSERT INTO fresh_finance_account_details "
   "(account_id,provider_id,subtype,confirmed_iso) VALUES(?,?,?,?)",
   ['old-rajhi','rajhi','current',date]);
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m942-v1-');
  db=WaffraEncryptedStore.openAt(
   File('${dir.path}/bank-v1.sqlite'),key:key);
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAtomicFinanceSnapshot(
   store:db,experimentalEnabled:true).initializeEmpty();
  await WaffraAccountsSchema.install(db);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });
 test('M942 v1 metadata migrates atomically, preserving opening and IDs',()async{
  await seedV1();
  expect(await revision(),1);
  await WaffraAccountDetailsSchema.requireReady(db);
  expect((await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances()).single.balanceMinor,420050);
  await WaffraAccountDetailsSchema.install(db);
  expect(await revision(),2);
  expect(await count('fresh_finance_account_details'),1);
  expect(await count('fresh_finance_entries'),0);
  final old=await db.customSelect(
   "SELECT account_id,provider_id,subtype FROM "
   "fresh_finance_account_details WHERE account_id='old-rajhi'").getSingle();
  expect(old.read<String>('provider_id'),'rajhi');
  expect(old.read<String>('subtype'),'current');

  final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
  await accounts.createAccount(id:'new-d360',name:'D360 - ادخار',
   kind:'bank',openingMinor:500000,createdIso:date,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(db,accountId:'new-d360',
   kind:'bank',providerId:'d360',subtype:'savings',confirmedIso:date);
  await accounts.createAccount(id:'new-barq',name:'برق - محفظة',
   kind:'wallet',openingMinor:200000,createdIso:date,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(db,accountId:'new-barq',
   kind:'wallet',providerId:'barq',subtype:'digital',confirmedIso:date);
  var list=await accounts.balances();
  expect({for(final a in list)a.id:a.balanceMinor},
   {'old-rajhi':420050,'new-d360':500000,'new-barq':200000});
  expect(list.fold<int>(0,(sum,a)=>sum+a.balanceMinor),1120050);
  expect(await count('fresh_finance_entries'),0);
  await db.close();
  db=WaffraEncryptedStore.openAt(File('${dir.path}/bank-v1.sqlite'),key:key);
  await WaffraAccountDetailsSchema.requireReady(db);
  expect(await revision(),2);
  list=await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances();
  expect({for(final a in list)a.id:a.providerId},
   {'old-rajhi':'rajhi','new-d360':'d360','new-barq':'barq'});
  expect(list.fold<int>(0,(sum,a)=>sum+a.balanceMinor),1120050);
  expect(await count('fresh_finance_entries'),0);
 });

 test('M942 failed migration preserves v1 source and original cash',()async{
  await seedV1();
  await db.customStatement(
   'CREATE TABLE fresh_finance_account_details_m942(ghost INTEGER)');
  await expectLater(WaffraAccountDetailsSchema.install(db),
   throwsA(anything));
  expect(await revision(),1);
  expect(await count('fresh_finance_account_details'),1);
  expect((await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances()).single.balanceMinor,420050);
  expect(await count('fresh_finance_entries'),0);
 });
}

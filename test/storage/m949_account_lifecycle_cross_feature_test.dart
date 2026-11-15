import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';

/// M949: NEW sequential account journeys. All fixtures use disposable SQLCipher.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore db;
 const secret='m949-disposable-private-test-finance-key';
 WaffraAccountsRepository get accounts=>WaffraAccountsRepository(
   db:db,experimentalEnabled:true);
 Future<void> make(String id,int amount,{String kind='bank',String? name})=>
  accounts.createAccount(id:id,name:name??id,kind:kind,openingMinor:amount,
   createdIso:'2026-11-15T09:00:00',userConfirmed:true);
 Future<Map<String,int>> balances()async=>{for(final a in await accounts.balances())
  a.id:a.balanceMinor};
 Future<int> count(String table)async=>(await db.customSelect(
  'SELECT count(*) AS n FROM '+table).getSingle()).read<int>('n');
 Future<bool> move(String id,String from,String to,int minor,{String note=''})=>
  accounts.transfer(id:id,fromAccountId:from,toAccountId:to,
   amountMinor:minor,occurredIso:'2026-11-15T10:00:00',
   note:note,userConfirmed:true);
 Future<void> insertOld(String id,int minor,{bool income=true})async{
  final data={'id':id,'title':'Historical '+id,'category':'General',
   'income':income,'amount':minor/100,
   'date':'2026-10-12T10:00:00','receiptPath':null};
  await db.customStatement('INSERT INTO fresh_finance_entries '
   '(entry_id,title,category_snapshot,amount_minor,is_income,'
   'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',[
    id,data['title'],data['category'],minor,income?1:0,data['date'],
    jsonEncode(data)]);
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m949-account-');
  db=WaffraEncryptedStore.openAt(File(dir.path+'/safe.sqlite'),key:secret);
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await WaffraAccountsSchema.install(db);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('M949-A01 renamed bank retains identity after inbound and outbound transfers',()async{
  await make('bank',100000);await make('wallet',25000,kind:'wallet');
  await move('m1','bank','wallet',15000);
  await move('m2','wallet','bank',2500);
  final old=await balances();
  await accounts.renameAccount(id:'bank',name:'   مصرف مرتب   ',userConfirmed:true);
  final rows=await accounts.balances();
  expect(rows.singleWhere((r)=>r.id=='bank').name,'مصرف مرتب');
  expect({for(final a in rows)a.id:a.balanceMinor},old);
  expect(await count('fresh_finance_internal_transfers'),2);
 });

 test('M949-A02 chained three-account transfer preserves each halala and total',()async{
  await make('salary',100001);await make('wallet',20002,kind:'wallet');
  await make('cash',30003,kind:'cash');
  final original=(await balances()).values.reduce((a,b)=>a+b);
  await move('chain1','salary','wallet',17555);
  await move('chain2','wallet','cash',9432);
  await move('chain3','cash','salary',711);
  expect(await balances(),{'salary':83157,'wallet':28125,'cash':38724});
  expect((await balances()).values.reduce((a,b)=>a+b),original);
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-A03 drain account to exact zero then archive, future source rejected',()async{
  await make('old',3300);await make('next',0);
  await move('empty-out','old','next',3300);
  await accounts.archiveEmptyAccount(id:'old',userConfirmed:true);
  expect((await accounts.balances()).singleWhere((a)=>a.id=='old').archived,true);
  await expectLater(move('after-archive','old','next',1),throwsStateError);
  expect(await balances(),{'old':0,'next':3300});
  expect(await count('fresh_finance_internal_transfers'),1);
 });

 test('M949-A04 zero-balance archived destination cannot receive new transfer',()async{
  await make('live',250);await make('retired',0);
  await accounts.archiveEmptyAccount(id:'retired',userConfirmed:true);
  await expectLater(move('to-closed','live','retired',10),throwsStateError);
  expect(await balances(),{'live':250,'retired':0});
  expect(await count('fresh_finance_internal_transfers'),0);
 });

 test('M949-A05 duplicate account ID with another kind and opening preserves original',()async{
  await make('original',13579,kind:'bank',name:'Original');
  await expectLater(make('original',99999,kind:'wallet',name:'Replacement'),
   throwsA(anything));
  expect((await accounts.balances()).single.kind,'bank');
  expect((await accounts.balances()).single.name,'Original');
  expect(await balances(),{'original':13579});
 });

 test('M949-A06 failed whitespace rename does not modify transfer ledger',()async{
  await make('account',500);await make('other',0);
  await move('prior','account','other',1);
  await expectLater(accounts.renameAccount(
   id:'account',name:' \t ',userConfirmed:true),throwsArgumentError);
  expect((await accounts.balances()).first.name,'account');
  expect(await balances(),{'account':499,'other':1});
  expect(await count('fresh_finance_internal_transfers'),1);
 });

 test('M949-A07 81 Unicode runes rejected on rename while saved money survives',()async{
  await make('account',9100);
  final invalid=List<String>.filled(81,'هـ').join();
  await expectLater(accounts.renameAccount(id:'account',name:invalid,
   userConfirmed:true),throwsArgumentError);
  expect((await accounts.balances()).single.name,'account');
  expect(await balances(),{'account':9100});
 });

 test('M949-A08 invalid account kind does not create partial financial owner',()async{
  await make('valid',100);
  await expectLater(make('invalid',400,kind:'unapproved-money-kind'),
   throwsArgumentError);
  expect(await balances(),{'valid':100});
  expect(await count('fresh_finance_money_accounts'),1);
 });

 test('M949-A09 corrupt account timestamp never creates historical owner',()async{
  await make('valid',250);
  await expectLater(accounts.createAccount(id:'broken',name:'Broken',
   kind:'bank',openingMinor:99,createdIso:'not-an-ISO-time',
   userConfirmed:true),throwsArgumentError);
  expect(await balances(),{'valid':250});
 });

 test('M949-A10 transfer replay changing ONLY its note fails without double debit',()async{
  await make('a',10000);await make('b',0);
  await move('same','a','b',300,note:'المصاريف');
  await expectLater(move('same','a','b',300,note:'رسوم جديدة'),throwsStateError);
  expect(await balances(),{'a':9700,'b':300});
  expect(await count('fresh_finance_internal_transfers'),1);
 });

 test('M949-A11 one-halalah transfer with long valid note then oversized note rollback',()async{
  await make('a',10);await make('b',0);
  final valid=List.filled(2000,'ك').join();
  expect(await move('one-halalah','a','b',1,note:valid),true);
  await expectLater(move('bad-note','a','b',2,note:valid+'ك'),
   throwsArgumentError);
  expect(await balances(),{'a':9,'b':1});
  expect(await count('fresh_finance_internal_transfers'),1);
 });

 test('M949-A12 separate transfers sharing one timestamp are not deduplicated',()async{
  await make('a',5000);await make('b',0);
  expect(await move('first','a','b',101),true);
  expect(await move('second','a','b',202),true);
  expect(await balances(),{'a':4697,'b':303});
  expect(await count('fresh_finance_internal_transfers'),2);
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-A13 partial historical mapping keeps existing bank link and maps only orphan',()async{
  await make('first',0);await make('second',0);
  await insertOld('old-linked',525);
  await insertOld('old-orphan',750);
  await accounts.linkEntry(entryId:'old-linked',accountId:'first',
   linkedIso:'2026-11-15T10:01:00',userConfirmed:true);
  final assigned=await accounts.linkHistoricalEntries(
   accountId:'second',linkedIso:'2026-11-15T10:02:00',
   userConfirmed:true,verifiedMigration:true);
  expect(assigned,1);
  expect(await accounts.linkHistoricalEntries(accountId:'second',
   linkedIso:'2026-11-15T10:03:00',userConfirmed:true,
   verifiedMigration:true),0);
  expect(await balances(),{'first':525,'second':750});
  final rows=await db.customSelect(
   'SELECT entry_id,account_id FROM fresh_finance_account_entry_links '
   'ORDER BY entry_id').get();
  expect(rows.map((r)=>[r.read<String>('entry_id'),r.read<String>('account_id')])
   .toList(),[['old-linked','first'],['old-orphan','second']]);
  expect(await count('fresh_finance_entries'),2);
 });

 test('M949-A14 linking missing transaction fails foreign key, never creates phantom link',()async{
  await make('bank',3333);
  await expectLater(accounts.linkEntry(entryId:'never-posted',
   accountId:'bank',linkedIso:'2026-11-15T10:00:00',userConfirmed:true),
   throwsA(anything));
  expect(await count('fresh_finance_account_entry_links'),0);
  expect(await balances(),{'bank':3333});
 });
}

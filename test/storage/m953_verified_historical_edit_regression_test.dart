import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _M953Source extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m953_disposable_verified_source',
 );
}

/// Real encrypted writer, never an in-memory fake save. The transaction
/// edit is limited to a single existing ID, preserving unrelated old SMS
/// raw JSON even where MoneyEntry's display projection has extra defaults.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory directory;
 late WaffraEncryptedStore store;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraVerifiedFinanceAuthority authority;
 late WaffraVerifiedEncryptedFinanceBridge bridge;
 String? key;

 setUp(()async{
  SharedPreferences.setMockInitialValues({});
  key=null;
  directory=await Directory.systemTemp.createTemp('waffra-m953-edit-');
  final install=await WaffraFreshInstallSource.prepareIn(
   directory,readKey:()async=>key,
   writeKey:(value)async{key=value;});
  expect(install,isNotNull);
  store=WaffraEncryptedStore.openAt(
   File('${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
   key:key!);
  snapshot=WaffraAtomicFinanceSnapshot(store:store,experimentalEnabled:true);
  final journal=WaffraEncryptedCutoverJournal(
   store:store,snapshot:snapshot,experimentalEnabled:true);
  bridge=WaffraVerifiedEncryptedFinanceBridge(
   snapshot:snapshot,cutoverJournal:journal,writerDirectory:directory,
   allWritersRoutedVerified:true,secureKeyVerified:true,
   experimentalEnabled:true);
  authority=WaffraVerifiedFinanceAuthority(
   sourceGuard:_M953Source(),freshInstall:install,
   encryptedSession:WaffraEncryptedFinanceSession(
    bridge:bridge,experimentalEnabled:true),
   encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
   verifiedKeyRecoveryInDevice:true);
  await WaffraFreshHomeCatalogRecovery.load(
   authority:authority,
   defaultCategoriesJson:jsonEncode(
    defaultCategories().map((e)=>e.toJson()).toList()));
  await WaffraAccountsRepository(db:store,experimentalEnabled:true)
   .createAccount(id:'cash',name:'Disposable cash',kind:'cash',
    openingMinor:12500,createdIso:'2026-11-15T00:00:00Z',
    userConfirmed:true);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });

 Map<String,Object?> entry(String id,{bool income=false,double amount=12.25})=>
  MoneyEntry(id:id,title:'Transaction $id',
   category:defaultCategories().firstWhere((c)=>
    c.income==income&&c.isSubcategory).name,
   amount:amount,income:income,
   date:DateTime.utc(2026,11,15,11,35)).toJson();

 Future<void> append(Map<String,Object?> row)async{
  await authority.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:row,userConfirmed:true,selectedAccountId:'cash',
   expectedAccountGeneration:(await snapshot.read()).generation);
 }

 Future<void> change({
  required String id,
  required Map<String,Object?> Function(Map<String,Object?>) edit,
 }) async {
  final before=await authority.load(
   route:WaffraFinanceRoute.transactionEdit);
  final items=(jsonDecode(before.ledgerRaw!) as List)
   .map((r)=>Map<String,Object?>.from(r as Map)).toList();
  final revised=<Map<String,Object?>>[];
  var touched=0;
  for(final row in items){
   if(row['id']==id){revised.add(edit(Map<String,Object?>.from(row)));touched++;}
   else revised.add(row);
  }
  expect(touched,1);
  final after=await authority.saveCaptured(
   route:WaffraFinanceRoute.transactionEdit,
   baseline:before,captured:<String,Object>{'entries':jsonEncode(revised)},
   userConfirmed:true);
  expect(after.ledgerRaw,isNotNull);
  expect((jsonDecode(after.ledgerRaw!) as List).length,items.length);
 }

 test('M953 old month and year edits never post another debit or lose income',()async{
  await append(entry('salary',income:true,amount:600));
  await append(entry('expense',amount:12.25));
  final before=await store.customSelect(
   'SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle();
  expect(before.read<int>('n'),2);
  await change(id:'expense',edit:(row)=>row
   ..['date']='2020-01-31T08:14:00.000Z');
  final rows=await store.customSelect(
   'SELECT entry_id,occurred_iso,amount_minor,is_income '
   'FROM fresh_finance_entries ORDER BY entry_id').get();
  expect(rows.length,2);
  expect(rows.first.read<String>('entry_id'),'expense');
  expect(rows.first.read<String>('occurred_iso'),
   '2020-01-31T08:14:00.000Z');
  expect(rows.first.read<int>('amount_minor'),1225);
  expect(rows.last.read<String>('entry_id'),'salary');
  expect(rows.last.read<int>('amount_minor'),60000);
  expect(rows.last.read<int>('is_income'),1);
  final balances=await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances();
  expect(balances.single.balanceMinor,12500+60000-1225);
 });

 test('M953 edit fields amount, notes, category, budget and date atomically',()async{
  await append(entry('expense',amount:15.5));
  final renamed=defaultCategories().firstWhere((c)=>
   !c.income&&c.isSubcategory&&c.name!=entry('x')['category']).name;
  await change(id:'expense',edit:(row)=>row
   ..['title']='Updated historical expense'
   ..['amount']=35.75
   ..['notes']='Verified note'
   ..['personalNotes']='Private manual note'
   ..['category']=renamed
   ..['date']='2024-02-29T13:59:00.000Z');
  final sql=await store.customSelect(
   "SELECT title,amount_minor,category_snapshot,occurred_iso,source_json "
   "FROM fresh_finance_entries WHERE entry_id='expense'").getSingle();
  expect(sql.read<int>('amount_minor'),3575);
  expect(sql.read<String>('category_snapshot'),renamed);
  expect(sql.read<String>('occurred_iso'),'2024-02-29T13:59:00.000Z');
  final raw=jsonDecode(sql.read<String>('source_json')) as Map;
  expect(raw['notes'],'Verified note');
  expect(raw['title'],'Updated historical expense');
  expect(raw['personalNotes'],'Private manual note');
  // Merely editing metadata does not manufacture a budget allocation.
  final allocations=await store.customSelect(
   'SELECT COUNT(*) AS n FROM fresh_finance_standalone_allocations')
   .getSingle();
  expect(allocations.read<int>('n'),0);
 });

 test('M953 immutable ID and source list survive raw SMS edit',()async{
  const hash='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  final sms=<String,Object?>{
   'id':'bank-sms','title':'Original bank SMS',
   'category':defaultCategories().firstWhere((c)=>
    !c.income&&c.isSubcategory).name,
   'amount':80.0,'income':false,'date':'2026-11-15T06:00:00Z',
   'sourceType':'sms','notes':'Original exact text',
  };
  await authority.commitConfirmedSms(
   route:WaffraFinanceRoute.bulkSmsConfirmedSave,
   records:[sms],hashes:[hash],userConfirmed:true);
  await append(entry('other-income',income:true));
  final rawBefore=(jsonDecode((await authority.load(
   route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List);
  final other=Map<String,Object?>.from(rawBefore.last as Map);
  await change(id:'bank-sms',edit:(row)=>row
   ..['date']='2022-08-09T04:40:00.000Z'
   ..['title']='Renamed SMS entry');
  final after=(jsonDecode((await authority.load(
   route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List);
  expect(after.length,2);
  expect(after.last,other);
  final changed=Map<String,Object?>.from(after.first as Map);
  expect(changed['sourceType'],'sms');
  expect(changed['notes'],'Original exact text');
  expect(changed['date'],'2022-08-09T04:40:00.000Z');
  final hashes=(await snapshot.read()).values['waffra_sms_hashes_v1'] as List;
  expect(hashes,[hash]);
 });


 test('M956 existing old expense moves to another bank without double posting',()async{
  final accounts=WaffraAccountsRepository(db:store,experimentalEnabled:true);
  await accounts.createAccount(id:'second',name:'Second',kind:'bank',
   openingMinor:8000,createdIso:'2026-11-15T00:00:00Z',userConfirmed:true);
  await append(entry('expense',amount:12.25));
  final witness=await bridge.loadForHomeAndWidget();
  final old=Map<String,Object?>.from(
   (jsonDecode(witness.ledgerRaw!) as List).single as Map);
  final revised=Map<String,Object?>.from(old)
   ..['amount']=22.75..['date']='2020-02-29T10:30:00.000Z';
  await bridge.editExistingAndMoveAccount(
   baseline:witness,expectedOriginal:old,replacement:revised,
   fromAccountId:'cash',toAccountId:'second',userConfirmed:true);
  final balances=await accounts.balances();
  expect(balances.firstWhere((a)=>a.id=='cash').balanceMinor,12500);
  expect(balances.firstWhere((a)=>a.id=='second').balanceMinor,5725);
  final sql=await store.customSelect(
   'SELECT entry_id,amount_minor,occurred_iso FROM fresh_finance_entries').get();
  expect(sql.length,1);
  expect(sql.single.read<int>('amount_minor'),2275);
  expect(sql.single.read<String>('occurred_iso'),'2020-02-29T10:30:00.000Z');
  final link=await store.customSelect(
   "SELECT account_id FROM fresh_finance_account_entry_links WHERE entry_id='expense'").getSingle();
  expect(link.read<String>('account_id'),'second');
 });

 test('M956 rejects stale original account and rolls back ledger',()async{
  final accounts=WaffraAccountsRepository(db:store,experimentalEnabled:true);
  await accounts.createAccount(id:'second',name:'Second',kind:'bank',
   openingMinor:8000,createdIso:'2026-11-15T00:00:00Z',userConfirmed:true);
  await append(entry('expense',amount:12.25));
  final witness=await bridge.loadForHomeAndWidget();
  final old=Map<String,Object?>.from(
   (jsonDecode(witness.ledgerRaw!) as List).single as Map);
  final revised=Map<String,Object?>.from(old)..['amount']=99.0;
  final digest=(await snapshot.read()).digest;
  await expectLater(bridge.editExistingAndMoveAccount(
   baseline:witness,expectedOriginal:old,replacement:revised,
   fromAccountId:'wrong',toAccountId:'second',userConfirmed:true),
   throwsStateError);
  expect((await snapshot.read()).digest,digest);
  final balances=await accounts.balances();
  expect(balances.firstWhere((a)=>a.id=='cash').balanceMinor,11275);
  expect(balances.firstWhere((a)=>a.id=='second').balanceMinor,8000);
 });

 test('M953 stale edit and accidental inserted third row fail closed',()async{
  await append(entry('keep',amount:7));
  final baseline=await authority.load(route:WaffraFinanceRoute.transactionEdit);
  await change(id:'keep',edit:(r)=>r..['title']='Already updated');
  final current=(await snapshot.read()).digest;
  await expectLater(authority.saveCaptured(
   route:WaffraFinanceRoute.transactionEdit,
   baseline:baseline,captured:<String,Object>{
    'entries':jsonEncode([entry('keep'),entry('phantom')]),
   },userConfirmed:true),throwsStateError);
  expect((await snapshot.read()).digest,current);
  expect((jsonDecode((await authority.load(
   route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List).length,1);
 });
}

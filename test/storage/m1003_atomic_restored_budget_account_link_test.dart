import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show defaultCategories;
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

class _M1003Source extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 })async=>const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m1003_disposable_sqlcipher_restore');
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory directory;
 late WaffraEncryptedStore store;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraVerifiedEncryptedFinanceBridge bridge;
 late WaffraVerifiedFinanceAuthority authority;
 String? key;
 setUp(()async{
  SharedPreferences.setMockInitialValues({});
  key=null;
  directory=await Directory.systemTemp.createTemp('waffra-m1003-history-');
  final install=await WaffraFreshInstallSource.prepareIn(
   directory,readKey:()async=>key,writeKey:(value)async{key=value;});
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
   sourceGuard:_M1003Source(),freshInstall:install,
   encryptedSession:WaffraEncryptedFinanceSession(
    bridge:bridge,experimentalEnabled:true),
   encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
   verifiedKeyRecoveryInDevice:true);
  await WaffraFreshHomeCatalogRecovery.load(
   authority:authority,
   defaultCategoriesJson:jsonEncode(
    defaultCategories().map((e)=>e.toJson()).toList()));
  await WaffraAccountsRepository(db:store,experimentalEnabled:true)
   .createAccount(id:'cash',name:'Restored cash',kind:'cash',
    openingMinor:100000,createdIso:'2026-11-16T00:00:00Z',
    userConfirmed:true);
 });
 tearDown(()async{
  await store.close();
  if(await directory.exists())await directory.delete(recursive:true);
 });
 Future<void> seedUnassigned()async{
  const hash='cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  await authority.commitConfirmedSms(
   route:WaffraFinanceRoute.bulkSmsConfirmedSave,
   records:[<String,Object?>{
    'id':'restored-expense','title':'Old restored expense',
    'category':defaultCategories().firstWhere(
     (c)=>!c.income&&c.isSubcategory).name,
    'amount':25.0,'income':false,'date':'2024-07-11T09:40:00.000Z',
    'sourceType':'sms','notes':'Retained original imported SMS',
   }],hashes:[hash],userConfirmed:true);
 }
 Future<(WaffraEncryptedHomeWitness,Map<String,Object?>)> oldRow()async{
  final w=await bridge.loadForHomeAndWidget();
  final data=jsonDecode(w.ledgerRaw!) as List;
  expect(data.length,1);
  return (w,Map<String,Object?>.from(data.single as Map));
 }
 test('M1003 unchecked opening exclusion does not save budget/account',()async{
  await seedUnassigned();
  final (w,old)=await oldRow();
  final edited=Map<String,Object?>.from(old)
   ..['budgetId']='test-active-budget'..['notes']='Edited old note';
  final before=await snapshot.read();
  await expectLater(bridge.editExistingAndLinkUnassigned(
   baseline:w,expectedOriginal:old,replacement:edited,
   toAccountId:'cash',openingExcludesHistory:false,userConfirmed:true),
   throwsStateError);
  final after=await snapshot.read();
  expect(after.digest,before.digest);
  expect(after.generation,before.generation);
  final rows=await store.customSelect(
   "SELECT source_json FROM fresh_finance_entries WHERE entry_id='restored-expense'").get();
  expect(rows.length,1);
  expect(jsonDecode(rows.single.read<String>('source_json')),old);
  expect((await store.customSelect(
   'SELECT account_id FROM fresh_finance_account_entry_links').get()),isEmpty);
  expect((await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances()).single.balanceMinor,100000);
 });
 test('M1003 budget-only edit leaves restored transaction without a bank account',()async{
  await seedUnassigned();
  final before=await authority.load(
   route:WaffraFinanceRoute.transactionEdit);
  final old=Map<String,Object?>.from(
   (jsonDecode(before.ledgerRaw!) as List).single as Map);
  final edited=Map<String,Object?>.from(old)
   ..['budgetId']='test-active-budget';
  final after=await authority.saveCaptured(
   route:WaffraFinanceRoute.transactionEdit,
   baseline:before,captured:<String,Object>{'entries':jsonEncode([edited])},
   userConfirmed:true);
  final saved=jsonDecode(after.ledgerRaw!) as List;
  expect(saved.length,1);
  expect((saved.single as Map)['budgetId'],'test-active-budget');
  expect((saved.single as Map)['id'],'restored-expense');
  expect((await store.customSelect(
   'SELECT account_id FROM fresh_finance_account_entry_links').get()),isEmpty);
  expect((await store.customSelect(
   'SELECT entry_id FROM fresh_finance_entries').get()).length,1);
  expect((await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances()).single.balanceMinor,100000);
 });
 test('M1003 confirmed restored edit links one record without double debit',()async{
  await seedUnassigned();
  final (w,old)=await oldRow();
  final edited=Map<String,Object?>.from(old)
   ..['budgetId']='test-active-budget'..['notes']='Reviewed old note';
  await bridge.editExistingAndLinkUnassigned(
   baseline:w,expectedOriginal:old,replacement:edited,
   toAccountId:'cash',openingExcludesHistory:true,userConfirmed:true);
  final verified=await bridge.loadForHomeAndWidget();
  final ledger=jsonDecode(verified.ledgerRaw!) as List;
  expect(ledger.length,1);
  expect((ledger.single as Map)['budgetId'],'test-active-budget');
  expect((ledger.single as Map)['notes'],'Reviewed old note');
  final rows=await store.customSelect(
   'SELECT entry_id,source_json FROM fresh_finance_entries').get();
  expect(rows.length,1);
  expect(rows.single.read<String>('entry_id'),'restored-expense');
  expect(jsonDecode(rows.single.read<String>('source_json')),edited);
  final links=await store.customSelect(
   'SELECT entry_id,account_id FROM fresh_finance_account_entry_links').get();
  expect(links.length,1);
  expect(links.single.read<String>('account_id'),'cash');
  final balance=(await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances()).single.balanceMinor;
  expect(balance,97500);
  await expectLater(bridge.editExistingAndLinkUnassigned(
   baseline:w,expectedOriginal:old,replacement:edited,
   toAccountId:'cash',openingExcludesHistory:true,userConfirmed:true),
   throwsStateError);
  expect((await WaffraAccountsRepository(
   db:store,experimentalEnabled:true).balances()).single.balanceMinor,97500);
 });
 test('M1003 missing account, bad ID and stale source roll back all fields',()async{
  await seedUnassigned();
  final (w,old)=await oldRow();
  final edited=Map<String,Object?>.from(old)..['budgetId']='test-budget';
  final digest=(await snapshot.read()).digest;
  await expectLater(bridge.editExistingAndLinkUnassigned(
   baseline:w,expectedOriginal:old,replacement:edited,
   toAccountId:'missing-account',openingExcludesHistory:true,
   userConfirmed:true),throwsStateError);
  expect((await snapshot.read()).digest,digest);
  final bad=Map<String,Object?>.from(edited)..['id']='tampered';
  await expectLater(bridge.editExistingAndLinkUnassigned(
   baseline:w,expectedOriginal:old,replacement:bad,
   toAccountId:'cash',openingExcludesHistory:true,userConfirmed:true),
   throwsStateError);
  expect((await snapshot.read()).digest,digest);
  expect((await store.customSelect(
   'SELECT account_id FROM fresh_finance_account_entry_links').get()),isEmpty);
 });
}

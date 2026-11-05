import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _M466ActiveSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 })async=>const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m466_disposable_verified_receipt_source',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore store;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraVerifiedFinanceAuthority authority;
 String? key;

 Map<String,Object?> record(String id,bool income)=>MoneyEntry(
  id:id,title:income?'Synthetic salary':'Synthetic groceries',
  category:defaultCategories().firstWhere(
   (c)=>c.income==income&&c.isSubcategory).name,
  amount:income?250.0:52.75,income:income,
  date:DateTime.utc(2026,11,5,12,30),
  notes:'Synthetic manually entered finance with selected category',
 ).toJson();

 setUp(()async{
  SharedPreferences.setMockInitialValues({});
  key=null;
  dir=await Directory.systemTemp.createTemp('waffra-m466-');
  final origin=await WaffraFreshInstallSource.prepareIn(dir,
   readKey:()async=>key,writeKey:(value)async{key=value;});
  expect(origin,isNotNull);
  store=WaffraEncryptedStore.openAt(
   File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
   key:key!);
  snapshot=WaffraAtomicFinanceSnapshot(
   store:store,experimentalEnabled:true);
  final bridge=WaffraVerifiedEncryptedFinanceBridge(
   snapshot:snapshot,
   cutoverJournal:WaffraEncryptedCutoverJournal(
    store:store,snapshot:snapshot,experimentalEnabled:true),
   writerDirectory:dir,allWritersRoutedVerified:true,
   secureKeyVerified:true,experimentalEnabled:true);
  authority=WaffraVerifiedFinanceAuthority(
   sourceGuard:_M466ActiveSource(),freshInstall:origin,
   encryptedSession:WaffraEncryptedFinanceSession(
    bridge:bridge,experimentalEnabled:true),
   encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
   verifiedKeyRecoveryInDevice:true);
  await WaffraFreshHomeCatalogRecovery.load(
   authority:authority,
   defaultCategoriesJson:jsonEncode(
    defaultCategories().map((c)=>c.toJson()).toList()));
  await WaffraAccountsRepository(db:store,experimentalEnabled:true)
    .createAccount(id:'verified-bank',name:'Test bank',kind:'bank',
     openingMinor:0,createdIso:'2026-11-05T00:00:00Z',
     userConfirmed:true);
 });
 tearDown(()async{
  await store.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('M466 manual expense and income with attached photos commit with '
   'the account under one encrypted source',()async{
  final original=(await snapshot.read()).values;
  for(final kind in <bool>[false,true]){
   final id=kind?'m466-income':'m466-expense';
   final pics=<Uint8List>[
    Uint8List.fromList([1,2,3,4,5,6]),
    Uint8List.fromList([8,9,10,11]),
   ];
   final current=await snapshot.read();
   final saved=await authority.commitConfirmedManual(
    route:WaffraFinanceRoute.manualTransactionSave,
    record:record(id,kind),receiptImages:pics,
    selectedAccountId:'verified-bank',
    expectedAccountGeneration:current.generation,userConfirmed:true);
   final ledger=jsonDecode(saved.ledgerRaw!) as List;
   final row=ledger.cast<Map>().singleWhere((x)=>x['id']==id);
   final refs=jsonDecode(row['receiptPath'] as String) as List;
   expect(refs,[WaffraEncryptedReceiptReference.of(id,0),
    WaffraEncryptedReceiptReference.of(id,1)]);
   expect(row['sourceType'],'manual');
   expect(row['income'],kind);
   final link=await store.customSelect(
    'SELECT account_id FROM fresh_finance_account_entry_links '
    'WHERE entry_id=?',variables:[Variable.withString(id)]).getSingle();
   expect(link.read<String>('account_id'),'verified-bank');
   final sql=await store.customSelect(
    'SELECT receipt_count,amount_minor,is_income FROM '
    'fresh_finance_entries WHERE entry_id=?',
    variables:[Variable.withString(id)]).getSingle();
   expect(sql.read<int>('receipt_count'),2);
   expect(sql.read<int>('amount_minor'),kind?25000:5275);
   expect(sql.read<int>('is_income'),kind?1:0);
   final checked=await WaffraEncryptedReceiptVault(
    store:store,experimentalEnabled:true).readAll(id);
   expect(checked.map((x)=>x.bytes.toList()).toList(),
    pics.map((x)=>x.toList()).toList());
   final again=await authority.load(
    route:WaffraFinanceRoute.dashboardRead);
   expect((jsonDecode(again.ledgerRaw!) as List)
    .where((x)=>x is Map&&x['id']==id),hasLength(1));
  }
  final later=(await snapshot.read()).values;
  for(final key in <String>['waffra_goals_v24','waffra_recurring_v24',
   'waffra_sms_hashes_v1']){
   expect(later[key],original[key],reason:'Existing $key must be untouched.');
  }
 });

 test('M466 bad owner, plaintext receipt path and empty images never '
   'save partially or double-charge',()async{
  final original=await snapshot.read();
  final data=record('m466-refused',false);
  final pic=Uint8List.fromList([1,2,3]);
  await expectLater(authority.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:{...data,'receiptPath':'/tmp/plaintext-receipt.jpg'},
   receiptImages:[pic],userConfirmed:true,
   selectedAccountId:'verified-bank',
   expectedAccountGeneration:original.generation),throwsStateError);
  await expectLater(authority.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:data,receiptImages:[Uint8List(0)],userConfirmed:true,
   selectedAccountId:'verified-bank',
   expectedAccountGeneration:original.generation),throwsArgumentError);
  await expectLater(authority.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:data,receiptImages:[pic],userConfirmed:true,
   selectedAccountId:'unknown-bank',
   expectedAccountGeneration:original.generation),throwsStateError);
  expect((await snapshot.read()).digest,original.digest);
  expect((await store.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle())
    .read<int>('n'),0);
  expect((await store.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_account_entry_links').getSingle())
    .read<int>('n'),0);
 });

 test('M466 manual UI has one income expense transfer choice, with no '
   'separate transfer action and no attached-entry legacy fallback',(){
  final app=File('lib/main.dart').readAsStringSync();
  final option=app.substring(app.indexOf(' Future<void> openManualTransactionChoice()'),
   app.indexOf(' Future<void> entrySheet('));
  for(final id in ['waffra-manual-choice-income',
   'waffra-manual-choice-expense','waffra-manual-choice-transfer']){
   expect(option,contains(id));
  }
  expect(option,contains('await openVerifiedTransfer()'));
  expect(option,contains('await entrySheet(initialIncome:'));
  final menu=app.substring(app.indexOf('        if(tab==0&&!goalsOpened)...['),
   app.indexOf('        ]else if(goalsOpened||tab==3)...['));
  expect(menu,contains('_launchAddAction(openManualTransactionChoice'));
  expect(menu,isNot(contains('_launchAddAction(openVerifiedTransfer')));
  final flow=app.substring(app.indexOf('   final chosenManual=initial==null'),
   app.indexOf('  if(mounted)await budgetAlert(result,previousSpent);'));
  expect(flow,contains("if(initial==null&&result.sourceType=='manual')"));
  expect(flow,contains("record['receiptPath']=null"));
  expect(flow,contains('receiptImages:images'));
  expect(flow,contains('selectedAccountId:chosenManual?.ids?.single'));
  expect(flow,contains('expectedAccountGeneration:'));
  expect(flow,isNot(contains("result.receiptPath!.isEmpty")));
  expect(app,contains('Image.memory(encryptedImages![index]'));
  expect(app,contains('WaffraEncryptedReceiptReference.matches'));
 });
}

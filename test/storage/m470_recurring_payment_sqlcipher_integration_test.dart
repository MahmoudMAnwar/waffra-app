import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, RecurringBill, defaultCategories;
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_verified_accounts_api.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _VerifiedSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m470-fresh-recurring-commit',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('M470 paid due saves once with required account in fresh SQLCipher',() async {
  SharedPreferences.setMockInitialValues({});
  final dir=await Directory.systemTemp.createTemp('m470-recurring-paid-');
  WaffraEncryptedStore? store;
  try{
   String? key;
   final origin=await WaffraFreshInstallSource.prepareIn(
    dir,readKey:()async=>key,writeKey:(v)async{key=v;});
   expect(origin,isNotNull);
   store=WaffraEncryptedStore.openAt(
    File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
    key:key!);
   final snapshot=WaffraAtomicFinanceSnapshot(
    store:store,experimentalEnabled:true);
   final bridge=WaffraVerifiedEncryptedFinanceBridge(
    snapshot:snapshot,cutoverJournal:WaffraEncryptedCutoverJournal(
     store:store,snapshot:snapshot,experimentalEnabled:true),
    writerDirectory:dir,allWritersRoutedVerified:true,
    secureKeyVerified:true,experimentalEnabled:true);
   final authority=WaffraVerifiedFinanceAuthority(
    sourceGuard:_VerifiedSource(),freshInstall:origin,
    encryptedSession:WaffraEncryptedFinanceSession(
     bridge:bridge,experimentalEnabled:true),
    encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
    verifiedKeyRecoveryInDevice:true);
   await WaffraFreshHomeCatalogRecovery.load(
    authority:authority,
    defaultCategoriesJson:jsonEncode(
     defaultCategories().map((x)=>x.toJson()).toList()));
   await WaffraAccountsRepository(db:store,experimentalEnabled:true)
    .createAccount(id:'cash',name:'Cash',kind:'cash',
     openingMinor:20000,createdIso:'2026-11-01T00:00:00Z',
     userConfirmed:true);

   // User-confirmed bank identifier is created in the same encrypted
   // account transaction, not in a second optional metadata write.
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   await api.balances();
   await api.createBankAccountWithVerifiedSuffix(
    id:'rajhi',name:'مصرف الراجحي - الجاري',
    openingMinor:0,createdIso:'2026-11-02T00:00:00Z',
    lastFour:'1234',userConfirmed:true);
   final account=await store.customSelect(
    "SELECT account_id FROM fresh_finance_money_accounts "
    "WHERE account_id='rajhi'").get();
   expect(account.length,1);
   final suffix=await store.customSelect(
    "SELECT last_four FROM fresh_finance_account_sms_suffixes "
    "WHERE account_id='rajhi'").get();
   expect(suffix.single.read<String>('last_four'),'1234');
   await api.balances();
   await expectLater(api.createBankAccountWithVerifiedSuffix(
    id:'invalid-bank',name:'Invalid bank',openingMinor:0,
    createdIso:'2026-11-02T00:00:00Z',
    lastFour:'123',userConfirmed:true),throwsArgumentError);
   final invalid=await store.customSelect(
    "SELECT account_id FROM fresh_finance_money_accounts "
    "WHERE account_id='invalid-bank'").get();
   expect(invalid,isEmpty);
   final category=defaultCategories().firstWhere(
    (x)=>!x.income&&x.isSubcategory).name;
   const id='electricity';
   final schedule=RecurringBill(
    id:id,title:'Electricity',category:category,
    amount:100,income:false,day:5,
    startAt:DateTime.utc(2026,11,1),accountId:'cash');
   final before=await authority.load(route:WaffraFinanceRoute.dashboardRead);
   final create=<String,Object>{
    'entries':'[]',
    'waffra_categories_v24':before.finance.getString('waffra_categories_v24')!,
    'waffra_recurring_v24':jsonEncode([schedule.toJson()]),
    'waffra_named_budgets_v1':'[]',
    'waffra_goals_v24':'[]',
   };
   WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
    route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    source:before.source,snapshot:create,
    witnessedValues:before.encryptedWitness!.snapshot.values);
   final afterCreate=await authority.saveCaptured(
    route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    baseline:before,captured:create);

   final defaultRows=await store.customSelect(
    "SELECT account_id FROM fresh_finance_recurring_account_defaults "
    "WHERE recurring_id='electricity'").get();
   expect(defaultRows.single.read<String>('account_id'),'cash');
   // A failed recurring creation must not leave an account-default row
   // or a partly-created typed schedule behind.
   final rejected=RecurringBill(
    id:'invalid-template',title:'Invalid',category:category,
    amount:10,income:false,day:5,startAt:DateTime.utc(2026,11,1),
    accountId:'missing');
   final bad=<String,Object>{
    'waffra_recurring_v24':jsonEncode([schedule.toJson(),rejected.toJson()]),
   };
   WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
    route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    source:afterCreate.source,snapshot:bad,
    witnessedValues:afterCreate.encryptedWitness!.snapshot.values);
   await expectLater(authority.saveCaptured(
    route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    baseline:afterCreate,captured:bad),throwsStateError);
   final ghost=await store.customSelect(
    "SELECT recurring_id FROM fresh_finance_recurring "
    "WHERE recurring_id='invalid-template'").get();
   expect(ghost,isEmpty);
   final due=MoneyEntry(id:'rec_electricity_2026_11',
    title:'Electricity',category:category,amount:100,
    income:false,date:DateTime.utc(2026,11,5),sourceType:'recurring');
   final capture=<String,Object>{
    'entries':jsonEncode([due.toJson()]),
    'waffra_categories_v24':afterCreate.finance.getString('waffra_categories_v24')!,
    'waffra_named_budgets_v1':'[]',
    'waffra_goals_v24':'[]',
    'waffra_recurring_v24':jsonEncode([schedule.toJson()]),
    'waffra_recurring_postponed_v1':'{}',
   };
   WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
    route:WaffraFinanceRoute.recurringPostingAndPostponement,
    source:afterCreate.source,snapshot:capture,
    witnessedValues:afterCreate.encryptedWitness!.snapshot.values);
   expect(capture.keys.toSet(),{'entries','waffra_recurring_postponed_v1'});
   final afterPaid=await authority.saveCaptured(
    route:WaffraFinanceRoute.recurringPostingAndPostponement,
    baseline:afterCreate,captured:capture,
    userConfirmed:true,selectedAccountId:'cash');
   expect((jsonDecode(afterPaid.ledgerRaw!) as List),hasLength(1));
   final posted=await store.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle();
   expect(posted.read<int>('n'),1);
   final linked=await store.customSelect(
    "SELECT COUNT(*) AS n FROM fresh_finance_account_entry_links "
    "WHERE entry_id='rec_electricity_2026_11' AND account_id='cash'",
   ).getSingle();
   expect(linked.read<int>('n'),1);
   final balances=await WaffraAccountsRepository(
    db:store,experimentalEnabled:true).balances();
   expect(balances.singleWhere((a)=>a.id=='cash').balanceMinor,10000);
   await expectLater(
    authority.saveCaptured(
     route:WaffraFinanceRoute.recurringPostingAndPostponement,
     baseline:afterPaid,captured:capture,
     userConfirmed:true,selectedAccountId:'cash'),
    throwsStateError);
  }finally{
   if(store!=null)await store.close();
   if(await dir.exists())await dir.delete(recursive:true);
  }
 });
}

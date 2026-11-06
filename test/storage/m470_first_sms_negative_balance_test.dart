import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_verified_accounts_api.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _VerifiedSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m470-first-sms-expense-verified',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('M470 #11: zero opening and one 200 SAR SMS expense yields -200 SAR; duplicate does not debit again',()async{
  SharedPreferences.setMockInitialValues({});
  final dir=await Directory.systemTemp.createTemp('m470-first-sms-expense-');
  WaffraEncryptedStore? store;
  try{
   String? key;
   final fresh=await WaffraFreshInstallSource.prepareIn(
    dir,readKey:()async=>key,writeKey:(v)async{key=v;});
   expect(fresh,isNotNull);
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
    sourceGuard:_VerifiedSource(),freshInstall:fresh,
    encryptedSession:WaffraEncryptedFinanceSession(
     bridge:bridge,experimentalEnabled:true),
    encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
    verifiedKeyRecoveryInDevice:true);
   await WaffraFreshHomeCatalogRecovery.load(
    authority:authority,defaultCategoriesJson:jsonEncode(
     defaultCategories().map((c)=>c.toJson()).toList()));
   // The existing verified API handles explicit account+typed identity
   // creation, not a guessed bank account or a second balance writer.
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   await api.balances();
   await api.createTypedAccountWithIdentity(
    id:'alinma-first',name:'AlinmaPay',kind:'bank',
    providerId:'inma',subtype:'current',openingMinor:0,
    createdIso:'2026-11-06T00:00:00Z',
    userConfirmed:true);
   final witnessed=await bridge.readVerifiedAccounts();
   final expense=MoneyEntry(
    id:'sms-alinma-expense-001',title:'First bank expense',
    category:defaultCategories().firstWhere(
     (c)=>!c.income&&c.isSubcategory).name,
    amount:200,income:false,date:DateTime.utc(2026,11,6),
    notes:'AlinmaPay: SAR 200.00 bank expense',
    sourceType:'sms',
   );
   const digest='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
   final commit=await authority.commitConfirmedSms(
    route:WaffraFinanceRoute.bulkSmsConfirmedSave,
    records:[Map<String,Object?>.from(expense.toJson())],
    hashes:[digest],userConfirmed:true,
    selectedAccountIds:['alinma-first'],
    expectedAccountGeneration:witnessed.witness.generation);
   expect(commit.saved,1);
   final balances=await WaffraAccountsRepository(
    db:store,experimentalEnabled:true).balances();
   expect(balances.singleWhere((a)=>a.id=='alinma-first').balanceMinor,-20000);
   final links=await store.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_account_entry_links '
    "WHERE account_id='alinma-first'").getSingle();
   expect(links.read<int>('n'),1);
   final refreshed=await bridge.readVerifiedAccounts();
   final ignored=await authority.commitConfirmedSms(
    route:WaffraFinanceRoute.bulkSmsConfirmedSave,
    records:[Map<String,Object?>.from(expense.toJson())..['id']='sms-duplicate-attempt'],
    hashes:[digest],userConfirmed:true,
    selectedAccountIds:['alinma-first'],
    expectedAccountGeneration:refreshed.witness.generation);
   expect(ignored.saved,0);
   expect(ignored.skippedDuplicates,1);
   final afterwards=await WaffraAccountsRepository(
    db:store,experimentalEnabled:true).balances();
   expect(afterwards.singleWhere((a)=>a.id=='alinma-first').balanceMinor,-20000);
   final ledgerRows=await store.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle();
   expect(ledgerRows.read<int>('n'),1);
  }finally{
   if(store!=null)await store.close();
   if(await dir.exists())await dir.delete(recursive:true);
  }
 });
}

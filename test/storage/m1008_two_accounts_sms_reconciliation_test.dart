import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_accounts_api.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _M1008VerifiedSource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 })async=>const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m1008-real-two-account-sms-parity',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M1008 two accounts + three confirmed SMS: source balances, all-time '
  'links and distinct current-month nets stay exact on encrypted SQLCipher',
  ()async{
  SharedPreferences.setMockInitialValues({});
  final dir=await Directory.systemTemp.createTemp('m1008-two-accounts-');
  WaffraEncryptedStore? db;
  try{
   String? key;
   final fresh=await WaffraFreshInstallSource.prepareIn(
    dir,readKey:()async=>key,writeKey:(value)async{key=value;});
   expect(fresh,isNotNull);
   db=WaffraEncryptedStore.openAt(
    File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
    key:key!);
   final snapshot=WaffraAtomicFinanceSnapshot(
    store:db,experimentalEnabled:true);
   final bridge=WaffraVerifiedEncryptedFinanceBridge(
    snapshot:snapshot,
    cutoverJournal:WaffraEncryptedCutoverJournal(
     store:db,snapshot:snapshot,experimentalEnabled:true),
    writerDirectory:dir,allWritersRoutedVerified:true,
    secureKeyVerified:true,experimentalEnabled:true);
   final authority=WaffraVerifiedFinanceAuthority(
    sourceGuard:_M1008VerifiedSource(),freshInstall:fresh,
    encryptedSession:WaffraEncryptedFinanceSession(
     bridge:bridge,experimentalEnabled:true),
    encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
    verifiedKeyRecoveryInDevice:true);
   await WaffraFreshHomeCatalogRecovery.load(
    authority:authority,
    defaultCategoriesJson:jsonEncode(
     defaultCategories().map((c)=>c.toJson()).toList()));
   final api=WaffraVerifiedAccountsApi(bridge:bridge);
   await api.balances();
   await api.createAccount(id:'rajhi',name:'AlRajhiBank',
    kind:'bank',openingMinor:0,createdIso:'2026-10-01T08:00:00Z',
    userConfirmed:true);
   await api.createAccount(id:'alinma',name:'AlinmaPay',
    kind:'wallet',openingMinor:0,createdIso:'2026-10-01T08:01:00Z',
    userConfirmed:true);
   final expenseCategory=defaultCategories().firstWhere(
    (c)=>!c.income&&c.isSubcategory).name;
   final incomeCategory=defaultCategories().firstWhere(
    (c)=>c.income&&c.isSubcategory).name;
   MoneyEntry message(String id,double amount,bool income,DateTime date)=>MoneyEntry(
    id:id,title:'Confirmed bank SMS $id',
    category:income?incomeCategory:expenseCategory,
    amount:amount,income:income,date:date,
    notes:'M1008 synthetic no OTP',sourceType:'sms');
   Future<int> post(MoneyEntry entry,String account,String hash)async{
    final witness=await bridge.readVerifiedAccounts();
    final result=await authority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
     records:[Map<String,Object?>.from(entry.toJson())],
     hashes:[hash],userConfirmed:true,allowDuplicateHashes:false,
     selectedAccountIds:[account],
     expectedAccountGeneration:witness.witness.generation);
    return result.saved;
   }
   // Month-old activity explains why "this month's difference" is NOT the
   // same as the all-time current bank balance in the owner's screenshots.
   expect(await post(message('old-expense',230,false,DateTime(2026,10,15)),
    'rajhi','${'a'*64}'),1);
   final beforeNovember=await api.readHomeAccountView(
    monthIso:'2026-11',selectedAccountId:'rajhi');
   expect(beforeNovember.balances.singleWhere(
    (a)=>a.id=='rajhi').balanceMinor,-23000);
   expect(beforeNovember.entryIds,contains('old-expense'));
   expect(beforeNovember.entryIds,hasLength(1));

   expect(await post(message('nov-income',30,true,DateTime(2026,11,15)),
    'rajhi','${'b'*64}'),1);
   expect(await post(message('nov-expense',279.35,false,DateTime(2026,11,15)),
    'alinma','${'c'*64}'),1);

   final rajhi=await api.readHomeAccountView(
    monthIso:'2026-11',selectedAccountId:'rajhi');
   final alinma=await api.readHomeAccountView(
    monthIso:'2026-11',selectedAccountId:'alinma');
   final all=await api.readHomeAccountView(
    monthIso:'2026-11',selectedAccountId:'all');
   expect(rajhi.entryIds,{'old-expense','nov-income'});
   expect(alinma.entryIds,{'nov-expense'});
   expect(rajhi.balances.singleWhere((a)=>a.id=='rajhi').balanceMinor,-20000);
   expect(alinma.balances.singleWhere((a)=>a.id=='alinma').balanceMinor,-27935);
   expect(all.balances.fold<int>(0,(sum,a)=>sum+a.balanceMinor),-47935);
   final allMonth=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11');
   final bankMonth=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11',selectedAccountId:'rajhi');
   final walletMonth=await WaffraAccountContextRead.loadMonthEntries(
    store:db,monthIso:'2026-11',selectedAccountId:'alinma');
   expect(allMonth.map((e)=>e.id).toSet(),{'nov-income','nov-expense'});
   expect(bankMonth.map((e)=>e.id).toSet(),{'nov-income'});
   expect(walletMonth.map((e)=>e.id).toSet(),{'nov-expense'});
   int net(Iterable<WaffraAccountLedgerRow> rows)=>rows.fold<int>(
    0,(n,e)=>n+(e.income?e.amountMinor:-e.amountMinor));
   expect(net(bankMonth),3000);
   expect(net(walletMonth),-27935);
   expect(net(allMonth),-24935);
   expect(all.balances.fold<int>(0,(n,a)=>n+a.balanceMinor)-net(allMonth),
    -23000,reason:'Prior-month transactions explain the exact difference.');

   // Hash dedup must remain atomic despite subsequent refreshes and
   // switching between two account contexts.
   final savedAgain=await post(
    message('attempt-duplicate',279.35,false,DateTime(2026,11,15)),
    'alinma','${'c'*64}');
   expect(savedAgain,0);
   final after=await api.readHomeAccountView(
    monthIso:'2026-11',selectedAccountId:'alinma');
   expect(after.entryIds,{'nov-expense'});
   expect(after.balances.singleWhere((a)=>a.id=='alinma').balanceMinor,-27935);
   final linkCount=await db.customSelect(
    'SELECT COUNT(*) AS n FROM fresh_finance_account_entry_links').getSingle();
   expect(linkCount.read<int>('n'),3);
  }finally{
   await db?.close();
   if(await dir.exists())await dir.delete(recursive:true);
  }
 });
}

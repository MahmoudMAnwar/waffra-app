import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show SavingGoal, RecurringBill, MoneyEntry, defaultCategories;
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

class _M461Source extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source:WaffraProductionFinanceSource.encryptedRoutingRequired,
  reasonCode:'m461_verified_fresh_install',
 );
}

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore store;
 late WaffraVerifiedFinanceAuthority authority;
 String? key;
 setUp(() async {
  SharedPreferences.setMockInitialValues({});
  dir=await Directory.systemTemp.createTemp('waffra-m461-source-');
  key=null;
  final origin=await WaffraFreshInstallSource.prepareIn(
   dir,readKey:()async=>key,writeKey:(value)async{key=value;});
  expect(origin,isNotNull);
  store=WaffraEncryptedStore.openAt(File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),key:key!);
  final snapshot=WaffraAtomicFinanceSnapshot(
   store:store,experimentalEnabled:true);
  final bridge=WaffraVerifiedEncryptedFinanceBridge(
   snapshot:snapshot,
   cutoverJournal:WaffraEncryptedCutoverJournal(
    store:store,snapshot:snapshot,experimentalEnabled:true),
   writerDirectory:dir,allWritersRoutedVerified:true,
   secureKeyVerified:true,experimentalEnabled:true);
  authority=WaffraVerifiedFinanceAuthority(
   sourceGuard:_M461Source(),freshInstall:origin,
   encryptedSession:WaffraEncryptedFinanceSession(
    bridge:bridge,experimentalEnabled:true),
   encryptedSqlWitnessActive:true,externalSourceWitnessActive:true,
   verifiedKeyRecoveryInDevice:true);
  await WaffraFreshHomeCatalogRecovery.load(
   authority:authority,
   defaultCategoriesJson:jsonEncode(
    defaultCategories().map((x)=>x.toJson()).toList()));
 });
 tearDown(()async{await store.close();if(await dir.exists())await dir.delete(recursive:true);});

 test('fresh encrypted account accepts goal, linked due and recurring, then manual money',()async{
  final category=defaultCategories().firstWhere((x)=>!x.income&&x.isSubcategory).name;
  final income=defaultCategories().firstWhere((x)=>x.income&&x.isSubcategory).name;
  final goal=SavingGoal(id:'goal-new',name:'New trip',target:800,saved:0,
   dueDate:DateTime.utc(2026,12,15));
  final due=RecurringBill(id:'due-new',title:'Trip due',
   category:category,amount:800,income:false,day:15,
   startAt:DateTime.utc(2026,12,15),linkedGoalId:goal.id);
  var before=await authority.load(route:WaffraFinanceRoute.dashboardRead);
  final savedGoal=<String,Object>{
   'entries': '[]',
   'waffra_categories_v24':before.finance.getString('waffra_categories_v24')!,
   'waffra_named_budgets_v1':'[]',
   'waffra_goals_v24':jsonEncode([goal.toJson()]),
   'waffra_recurring_v24':jsonEncode([due.toJson()]),
   'waffra_challenges_v1':'[]',
   'waffra_deleted_goals_v1':'[]',
   'waffra_deleted_recurring_v1':'[]',
   'waffra_recurring_postponed_v1':'{}',
   'waffra_monthly_budget_v1':0.0,
   'waffra_monthly_budget_enabled_v1':false,
   'waffra_learned_merchants_v1':'{}',
  };
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.goalCreateEditDeleteRestore,
   source:before.source,snapshot:savedGoal,
   witnessedValues:before.encryptedWitness!.snapshot.values);
  expect(savedGoal.keys.toSet(),{'waffra_goals_v24','waffra_recurring_v24'});
  final afterGoal=await authority.saveCaptured(
   route:WaffraFinanceRoute.goalCreateEditDeleteRestore,
   baseline:before,captured:savedGoal);
  expect(jsonDecode(afterGoal.finance.getString('waffra_goals_v24')!) as List,hasLength(1));
  expect(jsonDecode(afterGoal.finance.getString('waffra_recurring_v24')!) as List,hasLength(1));
  final recurring=RecurringBill(id:'standalone',title:'Electricity',
   category:category,amount:100,income:false,day:8,
   startAt:DateTime.utc(2026,11,5));
  final savedRecurring=<String,Object>{
   'entries':'[]',
   'waffra_categories_v24':before.finance.getString('waffra_categories_v24')!,
   'waffra_goals_v24':afterGoal.finance.getString('waffra_goals_v24')!,
   'waffra_recurring_v24':jsonEncode([due.toJson(),recurring.toJson()]),
   'waffra_named_budgets_v1':'[]',
  };
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
   source:afterGoal.source,snapshot:savedRecurring,
   witnessedValues:afterGoal.encryptedWitness!.snapshot.values);
  expect(savedRecurring.keys.toList(),['waffra_recurring_v24']);
  final afterRecurring=await authority.saveCaptured(
   route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
   baseline:afterGoal,captured:savedRecurring);
  expect(jsonDecode(afterRecurring.finance.getString('waffra_recurring_v24')!) as List,hasLength(2));

  for(final transaction in [
   MoneyEntry(id:'manual-income',title:'Salary',category:income,
    income:true,amount:500,date:DateTime.utc(2026,11,5)),
   MoneyEntry(id:'manual-expense',title:'Food',category:category,
    income:false,amount:20,date:DateTime.utc(2026,11,5)),
  ]){
   await authority.commitConfirmedManual(
    route:WaffraFinanceRoute.manualTransactionSave,
    record:transaction.toJson(),userConfirmed:true);
  }
  final finalRead=await authority.load(route:WaffraFinanceRoute.dashboardRead);
  expect(jsonDecode(finalRead.ledgerRaw!) as List,hasLength(2));
  expect(jsonDecode(finalRead.finance.getString('waffra_goals_v24')!) as List,hasLength(1));
  expect(jsonDecode(finalRead.finance.getString('waffra_recurring_v24')!) as List,hasLength(2));
  final rows=await store.customSelect('SELECT COUNT(*) AS n FROM fresh_finance_entries').getSingle();
  expect(rows.read<int>('n'),2);
 });
}

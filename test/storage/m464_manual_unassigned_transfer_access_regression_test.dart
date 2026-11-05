import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry;
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _GuardedLegacySource extends WaffraProductionFinanceSourceGuard {
 @override
 Future<WaffraProductionFinanceSourceReport> inspect({
  SharedPreferences? preferences,
 }) async => const WaffraProductionFinanceSourceReport(
  source: WaffraProductionFinanceSource.guardedLegacy,
  reasonCode: 'm464_legacy_accountless_manual_regression',
 );
}

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory work;
 late WaffraVerifiedFinanceAuthority finance;
 setUp(()async{
  SharedPreferences.setMockInitialValues(<String,Object>{
   'entries':'[]',
   'waffra_goals_v24':'[{"id":"preserve-goal"}]',
   'waffra_recurring_v24':'[{"id":"preserve-recurring"}]',
   'waffra_sms_hashes_v1':<String>[List<String>.filled(64,'a').join()],
  });
  work=await Directory.systemTemp.createTemp('waffra-m464-');
  finance=WaffraVerifiedFinanceAuthority(
   sourceGuard:_GuardedLegacySource(),
   legacy:WaffraHomeFinancePersistence(
    coordinator:WaffraLegacyFinanceWriterCoordinator(
     testDirectory:work,testBypassNativeLock:true,
    ),
   ),
  );
 });
 tearDown(()async{
  if(await work.exists())await work.delete(recursive:true);
 });

 Map<String,Object?> item(String id,bool income)=>MoneyEntry(
  id:id,title:income?'Synthetic income':'Synthetic expense',
  category:income?'راتب':'مطاعم',amount:income?125:15.25,
  income:income,date:DateTime.utc(2026,11,5),
 ).toJson();

 test('Accountless manual expense and income append under existing legacy lock '
  'without changing goals, recurring, or SMS hashes',()async{
  final first=await finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:item('expense',false),userConfirmed:true,
  );
  expect(first.source,WaffraRuntimeFinanceBackend.guardedLegacy);
  expect((jsonDecode(first.ledgerRaw!) as List),hasLength(1));
  final second=await finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:item('income',true),userConfirmed:true,
  );
  final records=jsonDecode(second.ledgerRaw!) as List;
  expect(records.map((x)=>(x as Map)['id']).toList(),['expense','income']);
  final p=await SharedPreferences.getInstance();
  await p.reload();
  expect(p.getString('waffra_goals_v24'),'[{"id":"preserve-goal"}]');
  expect(p.getString('waffra_recurring_v24'),'[{"id":"preserve-recurring"}]');
  expect(p.getStringList('waffra_sms_hashes_v1'),[List<String>.filled(64,'a').join()]);
  await expectLater(finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:item('expense',false),userConfirmed:true,
  ),throwsStateError);
  expect((jsonDecode((await finance.load(
   route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List),hasLength(2));
 });

 test('Legacy cannot attach unverifiable account or post as SMS',()async{
  await expectLater(finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:item('bad-account',true),userConfirmed:true,
   selectedAccountId:'bank-1',expectedAccountGeneration:1,
  ),throwsStateError);
  await expectLater(finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:{...item('bad-sms',false),'sourceType':'sms'},userConfirmed:true,
  ),throwsStateError);
  await expectLater(finance.commitConfirmedManual(
   route:WaffraFinanceRoute.manualTransactionSave,
   record:item('not-confirmed',false),userConfirmed:false,
  ),throwsStateError);
  expect((jsonDecode((await finance.load(
   route:WaffraFinanceRoute.dashboardRead)).ledgerRaw!) as List),isEmpty);
 });

 test('Main plus button exposes transfer, account route and manual direct writer',
  () {
  final main=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  expect(main,contains("label:waffraIsEnglish?'Transfer between my accounts':'تحويل بين حساباتي'"));
  expect(main,contains('_launchAddAction(openVerifiedTransfer,fromMenu:true)'));
  expect(main,contains('initialOperation:WaffraAccountOperation.transfer'));
  expect(main,contains('accounts.where((a)=>!a.archived).length<2'));
  expect(main,contains('WaffraRuntimeFinanceBackend.guardedLegacy'));
  expect(main,contains('commitConfirmedManual('));
  expect(form,contains('mode=widget.initialOperation;'));
  expect(form,contains('widget.initialOperation==WaffraAccountOperation.transfer?null'));
 });
}

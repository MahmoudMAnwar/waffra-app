import 'dart:convert';
import 'dart:io';
import '../support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry;
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
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

 test('Guarded legacy rejects new accountless income and expense '
  'without changing historical finance or SMS',()async{
  for(final itemId in <String>['expense','income']){
   await expectLater(finance.commitConfirmedManual(
    route:WaffraFinanceRoute.manualTransactionSave,
    record:item(itemId,itemId=='income'),userConfirmed:true,
   ),throwsStateError);
  }
  final p=await SharedPreferences.getInstance();
  await p.reload();
  expect(p.getString('entries'),'[]');
  expect(p.getString('waffra_goals_v24'),'[{"id":"preserve-goal"}]');
  expect(p.getString('waffra_recurring_v24'),'[{"id":"preserve-recurring"}]');
  expect(p.getStringList('waffra_sms_hashes_v1'),
   [List<String>.filled(64,'a').join()]);
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
  // The fixture intentionally includes incomplete legacy goal/recurring
  // projections. An integrity-checked dashboard read must fail closed;
  // verify the rejected writes against durable storage instead.
  final p=await SharedPreferences.getInstance();
  await p.reload();
  expect(jsonDecode(p.getString('entries')!),isEmpty);
  expect(p.getString('waffra_goals_v24'),'[{"id":"preserve-goal"}]');
  expect(p.getString('waffra_recurring_v24'),'[{"id":"preserve-recurring"}]');
  expect(p.getStringList('waffra_sms_hashes_v1'),
   [List<String>.filled(64,'a').join()]);
  await expectLater(finance.load(
   route:WaffraFinanceRoute.dashboardRead),throwsStateError);
 });

 test('Main plus opens one manual popup with three modes, verified transfer and direct writer',
  () {
  final main=readWaffraMainSourceForContracts();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  final menuStart=main.indexOf("if(tab==0&&!goalsOpened)...[");
  final menuEnd=main.indexOf("]else if(goalsOpened||tab==3)...[",menuStart);
  expect(menuStart,greaterThan(0));
  expect(menuEnd,greaterThan(menuStart));
  final menu=main.substring(menuStart,menuEnd);
  expect(menu,contains("label:waffraIsEnglish?'Add manual transaction':'إضافة عملية يدوية'"));
  expect(menu,isNot(contains("_launchAddAction(openVerifiedTransfer,fromMenu:true)")));
  expect(main,contains("Key('waffra-manual-three-modes')"));
  expect(main,contains("Key('m466-confirm-transfer')"));
  expect(main,contains('await transferApi!.transfer('));
  expect(main,contains('WaffraRuntimeFinanceBackend.guardedLegacy'));
  expect(main,contains('commitConfirmedManual('));
  expect(form,contains('mode=widget.initialOperation;'));
  expect(form,contains('widget.initialOperation==WaffraAccountOperation.transfer?null'));
 });
}

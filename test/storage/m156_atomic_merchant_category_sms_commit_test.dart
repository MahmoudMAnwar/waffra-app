import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_finance_batch_journal.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory folder;
 WaffraHomeFinancePersistence bridge()=>WaffraHomeFinancePersistence(
  coordinator:WaffraLegacyFinanceWriterCoordinator(
   testDirectory:folder,testBypassNativeLock:true));
 Map<String,Object?> root(String id,String name,bool income)=> {
  'id':id,'name':name,'icon':'category','color':4278238040,
  'income':income,'parentId':'','budget':0.0,'alertPercent':80,
 };
 Map<String,Object?> child(String id,String name,String parent,bool income)=> {
  'id':id,'name':name,'icon':'category','color':4278238040,
  'income':income,'parentId':parent,'budget':0.0,'alertPercent':80,
 };
 Map<String,Object?> entry(String id,String category,bool income)=> {
  'id':id,'title':'شراء من تاجر','category':category,'amount':72.01,
  'income':income,'date':'2026-10-15T16:09:00',
  'receiptPath':null,'notes':'','sourceType':'sms','merchantKey':'sample',
 };
 final roots=[root('other','أخرى',false),root('transfer','تحويلات',false),
  root('incoming','حوالات واردة',true),root('other-income','دخل آخر',true)];

 setUp(()async{
  SharedPreferences.setMockInitialValues({
   'entries':'[]','waffra_categories_v24':jsonEncode(roots),
   'waffra_sms_hashes_v1':<String>[],
  });
  folder=await Directory.systemTemp.createTemp('waffra-m156-atomic-');
 });
 tearDown(()async{
  if(await folder.exists())await folder.delete(recursive:true);
 });
 test('M156: category + 2 entries + hashes + revision commit together',()async{
  final results=await bridge().commitConfirmedLegacySms(
   records:[entry('s1','أخرى / ALHUSSAIN',false),
    entry('s2','أخرى / ALHUSSAIN',false)],
   messageHashes:['a'*64,'b'*64],userConfirmed:true,
   proposedCategories:[child('merchant','أخرى / ALHUSSAIN','other',false)],
  );
  expect(results.added,2);
  final prefs=await SharedPreferences.getInstance();await prefs.reload();
  final saved=jsonDecode(prefs.getString('entries')!) as List;
  final cats=jsonDecode(prefs.getString('waffra_categories_v24')!) as List;
  expect(saved,length(2));expect(cats,length(5));
  expect(cats.last['name'],'أخرى / ALHUSSAIN');
  expect(prefs.getStringList('waffra_sms_hashes_v1'),['a'*64,'b'*64]);
  expect(prefs.getString('waffra_widget_last_save_v1'),isNotNull);
  expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),false);
 });
 test('M156: duplicate SMS never creates orphan category',()async{
  SharedPreferences.setMockInitialValues({
   'entries':jsonEncode([entry('existing','أخرى / Existing',false)]),
   'waffra_categories_v24':jsonEncode(roots),
   'waffra_sms_hashes_v1':<String>['a'*64],
  });
  final result=await bridge().commitConfirmedLegacySms(
   records:[entry('new','أخرى / A',false)],
   messageHashes:['a'*64],userConfirmed:true,
   proposedCategories:[child('catA','أخرى / A','other',false)],
  );
  expect(result.added,0);expect(result.skippedDuplicates,1);
  final prefs=await SharedPreferences.getInstance();
  expect((jsonDecode(prefs.getString('waffra_categories_v24')!) as List).length,4);
  expect((jsonDecode(prefs.getString('entries')!) as List).length,1);
 });
 test('M156: missing parent rejects ALL four keys without mutation',()async{
  final prefs=await SharedPreferences.getInstance();
  final baselineEntries=prefs.getString('entries'),baselineCats=prefs.getString('waffra_categories_v24');
  await expectLater(bridge().commitConfirmedLegacySms(
   records:[entry('e1','أخرى / ALHUSSAIN',false)],
   messageHashes:['a'*64],userConfirmed:true,
   proposedCategories:[child('bad','أخرى / ALHUSSAIN','missing',false)],
  ),throwsA(isA<StateError>()));
  await prefs.reload();
  expect(prefs.getString('entries'),baselineEntries);
  expect(prefs.getString('waffra_categories_v24'),baselineCats);
  expect(prefs.getStringList('waffra_sms_hashes_v1'),isEmpty);
  expect(prefs.getString('waffra_widget_last_save_v1'),isNull);
 });
 test('M156: interrupted partial multi-key write rolls forward on cold load',()async{
  final prefs=await SharedPreferences.getInstance();
  final next=entry('e1','أخرى / ALHUSSAIN',false);
  const journal=WaffraLegacyFinanceBatchJournal();
  await journal.prepare(prefs:prefs,nextValues:{
   'entries':jsonEncode([next]),
   'waffra_categories_v24':jsonEncode([...roots,
    child('merchant','أخرى / ALHUSSAIN','other',false)]),
   'waffra_sms_hashes_v1':<String>['a'*64],
   'waffra_widget_last_save_v1':'r-123',
  });
  // Simulate process death after entries only, before categories/hashes/revision.
  await prefs.setString('entries',jsonEncode([next]));
  final witness=await bridge().loadWithWitness();
  expect(witness.widgetRevision,'r-123');
  await prefs.reload();
  expect((jsonDecode(prefs.getString('waffra_categories_v24')!) as List),length(5));
  expect(prefs.getStringList('waffra_sms_hashes_v1'),['a'*64]);
  expect(prefs.containsKey(WaffraLegacyFinanceBatchJournal.pendingKey),false);
 });
}

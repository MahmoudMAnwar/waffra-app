import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory root;
 late WaffraEncryptedStore db;
 WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(
  store:db,experimentalEnabled:true);
 WaffraUnifiedFinanceWriter writer()=>WaffraUnifiedFinanceWriter(
  writerDirectory:root,snapshot:snapshot(),experimentalEnabled:true);
 const parent=<String,Object?>{
  'id':'other','name':'أخرى','parentId':'','income':false,'budget':0,
  'icon':'category','color':4278238040,'alertPercent':80,
 };
 const merchant=<String,Object?>{
  'id':'shop-1','name':'أخرى / ALHUSSAIN','parentId':'other',
  'income':false,'budget':0.0,'icon':'category','color':4278238040,
  'alertPercent':80,
 };
 Map<String,Object?> expense(String id)=> {
  'id':id,'title':'شراء من ALHUSSAIN','category':'أخرى / ALHUSSAIN',
  'amount':72.01,'income':false,'date':'2026-10-20T16:09:00',
  'receiptPath':null,'sourceType':'sms','merchantKey':'alhussain',
  'notes':'',
 };
 String digest(int v)=>v.toRadixString(16).padLeft(64,'0');
 Future<int> sqlCount(String table) async =>
  (await db.customSelect('SELECT count(*) AS n FROM $table').getSingle())
   .read<int>('n');
 setUp(()async{
  root=await Directory.systemTemp.createTemp('waffra-m156-sqlcipher-');
  db=WaffraEncryptedStore.openAt(
   File('${root.path}/finance.sqlite'),key:'m156-test-key-disposable-only');
  await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
   .initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await snapshot().initializeEmpty();
  final editor=WaffraEncryptedFinanceUiPatch(snapshot:snapshot(),
   writerDirectory:root,experimentalEnabled:true);
  await editor.saveScreenChanges(
   screenBaseline:(await snapshot().read()).values,
   replacementValues:{'waffra_categories_v24':jsonEncode([parent])},
   changedKeys:const {'waffra_categories_v24'});
 });
 tearDown(()async{
  await db.close();
  if(await root.exists())await root.delete(recursive:true);
 });
 test('M156 SQL: 2 confirmed transactions, merchant child, hashes share SQL commit',()async{
  final before=await snapshot().read();
  final saved=await writer().appendTransactions(
   records:[expense('one'),expense('two')],
   messageHashes:[digest(1),digest(2)],userConfirmed:true,
   proposedCategories:[merchant]);
  expect(saved.saved,2);
  final after=await snapshot().read();
  expect(after.generation,before.generation+1);
  expect((jsonDecode(after.values['entries'] as String) as List),hasLength(2));
  expect((jsonDecode(after.values['waffra_categories_v24'] as String) as List),hasLength(2));
  expect(after.values['waffra_sms_hashes_v1'],[digest(1),digest(2)]);
  expect(await sqlCount('fresh_finance_entries'),2);
  expect(await sqlCount('fresh_finance_categories'),2);
  expect(await sqlCount('fresh_finance_sms_hashes'),0); // unified snapshot owns hashes
 });
 test('M156 SQL: a repeated SMS cannot create an orphan new category',()async{
  final first=await writer().appendTransactions(
   records:[expense('one')],messageHashes:[digest(1)],
   userConfirmed:true,proposedCategories:[merchant]);
  expect(first.saved,1);
  const candidate=<String,Object?>{
   'id':'orphan','name':'أخرى / Different','parentId':'other',
   'income':false,'budget':0.0,'icon':'category','color':4278238040,
   'alertPercent':80,
  };
  final second=await writer().appendTransactions(
   records:[{...expense('two'),'category':'أخرى / Different'}],
   messageHashes:[digest(1)],userConfirmed:true,
   proposedCategories:[candidate]);
  expect(second.saved,0);expect(second.skippedDuplicates,1);
  expect(await sqlCount('fresh_finance_categories'),2);
  expect(await sqlCount('fresh_finance_entries'),1);
 });
 test('M156 SQL: missing category parent rolls back entries and hashes',()async{
  final previous=await snapshot().read();
  final invalid={...merchant,'parentId':'deleted-parent'};
  await expectLater(writer().appendTransactions(
   records:[expense('failed')],messageHashes:[digest(11)],
   proposedCategories:[invalid],userConfirmed:true),throwsStateError);
  final after=await snapshot().read();
  expect(after.generation,previous.generation);
  expect(await sqlCount('fresh_finance_entries'),0);
  expect(await sqlCount('fresh_finance_categories'),1);
  expect(after.values.containsKey('waffra_sms_hashes_v1'),false);
 });
 test('M156 SQL: category SQL trigger failure rolls back inserted ledger too',()async{
  await db.customStatement('''
CREATE TRIGGER fail_merchant
BEFORE INSERT ON fresh_finance_categories
WHEN NEW.category_id='shop-1'
BEGIN
 SELECT RAISE(ABORT, 'category insert failed');
END''');
  final baseline=await snapshot().read();
  await expectLater(writer().appendTransactions(
   records:[expense('failed')],messageHashes:[digest(31)],
   proposedCategories:[merchant],userConfirmed:true),throwsA(anything));
  final after=await snapshot().read();
  expect(after.generation,baseline.generation);
  expect(await sqlCount('fresh_finance_entries'),0);
  expect(await sqlCount('fresh_finance_categories'),1);
  expect(after.values.containsKey('waffra_sms_hashes_v1'),false);
 });
}

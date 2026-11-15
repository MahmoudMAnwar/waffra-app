import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

/// M949: NEW category -> goal -> recurring transitions, not primitive CRUD repeats.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory dir;
 late WaffraEncryptedStore db;
 const password='m949-synthetic-module-only-key';
 WaffraFreshModulesRepository get modules=>WaffraFreshModulesRepository(
  store:db,experimentalEnabled:true);
 WaffraAccountsRepository get accounts=>WaffraAccountsRepository(
  db:db,experimentalEnabled:true);
 Map<String,Object?> cat(String id,{String name='المعيشة',String parent='',
   bool income=false,double budget=0})=>{
    'id':id,'name':name,'parentId':parent,'income':income,
    'budget':budget,'icon':'category','color':123,
    'alertPercent':80};
 Map<String,Object?> goal(String id,{String name='هدف',double target=500,
  String? account='bank',bool active=true})=>{
   'id':id,'name':name,'target':target,'saved':0.0,
   'accountId':account,'active':active};
 Map<String,Object?> due(String id,{String? account='bank',
   String? linkedGoal, int day=15,double amount=25,
   bool active=true,String start='2026-11-15T10:00:00'})=>{
    'id':id,'title':'فاتورة '+id,'category':'فواتير',
    'amount':amount,'income':false,'day':day,'active':active,
    'startAt':start,'accountId':account,'linkedGoalId':linkedGoal};
 Future<Map<String,Object?>> only(WaffraFinanceModule module,String id)async=>
  (await modules.list(module)).singleWhere((v)=>v['id']==id);
 Future<int> count(String name)async=>(await db.customSelect(
  'SELECT count(*) AS n FROM '+name).getSingle()).read<int>('n');
 Future<String?> sourceDefault(String id)async{
  final r=await db.customSelect(
   'SELECT account_id FROM fresh_finance_recurring_account_defaults '
   'WHERE recurring_id=?',variables:[Variable.withString(id)]).get();
  return r.isEmpty?null:r.single.read<String>('account_id');
 }
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('waffra-m949-modules-');
  db=WaffraEncryptedStore.openAt(File(dir.path+'/modules.sqlite'),key:password);
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  for(final id in ['bank','wallet']){
   await accounts.createAccount(id:id,name:id,kind:id=='bank'?'bank':'wallet',
    openingMinor:id=='bank'?100000:50000,
    createdIso:'2026-11-15T09:00:00',userConfirmed:true);
  }
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 test('M949-M01 renaming parent category keeps existing child parent ID and kind',()async{
  await modules.save(WaffraFinanceModule.categories,cat('parent'));
  await modules.save(WaffraFinanceModule.categories,cat('child',
   name:'الحليب',parent:'parent'));
  await modules.save(WaffraFinanceModule.categories,cat('parent',
   name:'الأسرة'),replaceExisting:true);
  expect((await only(WaffraFinanceModule.categories,'child'))['parentId'],
   'parent');
  expect((await only(WaffraFinanceModule.categories,'parent'))['name'],
   'الأسرة');
  expect(await count('fresh_finance_categories'),2);
 });

 test('M949-M02 editing parent budget to one halala does not edit child budget',()async{
  await modules.save(WaffraFinanceModule.categories,cat('root',budget:100));
  await modules.save(WaffraFinanceModule.categories,cat('leaf',
   parent:'root',budget:20));
  await modules.save(WaffraFinanceModule.categories,cat('root',budget:0.01),
   replaceExisting:true);
  final typed=await db.customSelect(
   'SELECT category_id,budget_minor FROM fresh_finance_categories '
   'ORDER BY category_id').get();
  expect(typed.map((r)=>r.read<int>('budget_minor')).toList(),[2000,1]);
  expect((await only(WaffraFinanceModule.categories,'leaf'))['budget'],20.0);
 });

 test('M949-M03 reclassifying unused category to income updates typed and JSON together',()async{
  await modules.save(WaffraFinanceModule.categories,cat('unused'));
  await modules.save(WaffraFinanceModule.categories,cat('neighbor'));
  await modules.save(WaffraFinanceModule.categories,cat('unused',income:true),
   replaceExisting:true);
  final row=await db.customSelect(
   "SELECT is_income FROM fresh_finance_categories WHERE category_id='unused'")
   .getSingle();
  expect(row.read<int>('is_income'),1);
  expect((await only(WaffraFinanceModule.categories,'unused'))['income'],true);
  expect((await only(WaffraFinanceModule.categories,'neighbor'))['income'],false);
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-M04 multi-category list is sorted and cannot mutate encrypted saved maps',()async{
  for(final id in ['z','b','a']){
   await modules.save(WaffraFinanceModule.categories,cat(id));
  }
  final original=await modules.list(WaffraFinanceModule.categories);
  expect(original.map((e)=>e['id']).toList(),['a','b','z']);
  expect(()=>original.clear(),throwsUnsupportedError);
  expect(()=>original.first['name']='اختراق',throwsUnsupportedError);
  expect((await only(WaffraFinanceModule.categories,'a'))['name'],'المعيشة');
 });

 test('M949-M05 goal target and due-date edit preserves saved and linked schedule',()async{
  await modules.save(WaffraFinanceModule.goals,goal('travel'));
  await modules.save(WaffraFinanceModule.recurring,due('trip-due',
   linkedGoal:'travel'));
  await modules.save(WaffraFinanceModule.goals,{
   ...goal('travel',target:1250,name:'السفر'),
   'dueDate':'2028-02-29T00:00:00',
  },replaceExisting:true);
  final g=await only(WaffraFinanceModule.goals,'travel');
  final r=await only(WaffraFinanceModule.recurring,'trip-due');
  expect(g['target'],1250);
  expect(g['saved'],0.0);
  expect(g['dueDate'],'2028-02-29T00:00:00');
  expect(r['linkedGoalId'],'travel');
  expect(r['accountId'],'bank');
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-M06 invalid goal alert threshold rejects edit without changing neighbor',()async{
  await modules.save(WaffraFinanceModule.goals,goal('first'));
  await modules.save(WaffraFinanceModule.goals,goal('second',target:950));
  await expectLater(modules.save(WaffraFinanceModule.goals,{
   ...goal('first'),'progressAlertsEnabled':true,'progressAlertPercent':51,
  },replaceExisting:true),throwsArgumentError);
  expect((await only(WaffraFinanceModule.goals,'first'))['target'],500);
  expect((await only(WaffraFinanceModule.goals,'second'))['target'],950);
  expect(await count('fresh_finance_goals'),2);
 });

 test('M949-M07 changing saved goal to missing account fails, linked due unchanged',()async{
  await modules.save(WaffraFinanceModule.goals,goal('pension'));
  await modules.save(WaffraFinanceModule.recurring,
   due('pension-due',linkedGoal:'pension'));
  await expectLater(modules.save(WaffraFinanceModule.goals,
   goal('pension',account:'missing'),replaceExisting:true),throwsStateError);
  expect((await only(WaffraFinanceModule.goals,'pension'))['accountId'],'bank');
  expect((await only(WaffraFinanceModule.recurring,'pension-due'))['accountId'],
   'bank');
  expect(await sourceDefault('pension-due'),'bank');
 });

 test('M949-M08 bank rename keeps verified linked-goal due account identity',()async{
  await modules.save(WaffraFinanceModule.goals,goal('savings'));
  await accounts.renameAccount(id:'bank',name:'مصرف جديد',userConfirmed:true);
  await modules.save(WaffraFinanceModule.recurring,due('rent',
   linkedGoal:'savings'));
  expect((await only(WaffraFinanceModule.recurring,'rent'))['accountId'],'bank');
  expect(await sourceDefault('rent'),'bank');
  expect((await accounts.balances()).singleWhere((a)=>a.id=='bank').name,
   'مصرف جديد');
 });

 test('M949-M09 switching one recurring default leaves another schedule bound',()async{
  await modules.save(WaffraFinanceModule.recurring,due('rent'));
  await modules.save(WaffraFinanceModule.recurring,due('phone'));
  await modules.save(WaffraFinanceModule.recurring,
   due('rent',account:'wallet'),replaceExisting:true);
  expect(await sourceDefault('rent'),'wallet');
  expect(await sourceDefault('phone'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'rent'))['accountId'],'wallet');
  expect((await only(WaffraFinanceModule.recurring,'phone'))['accountId'],'bank');
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-M10 unlink goal first, then change recurring account without spending savings',()async{
  await modules.save(WaffraFinanceModule.goals,goal('target'));
  await modules.save(WaffraFinanceModule.recurring,
   due('scheduled',linkedGoal:'target'));
  final revised=due('scheduled',account:'wallet');
  await modules.save(WaffraFinanceModule.recurring,revised,replaceExisting:true);
  expect((await only(WaffraFinanceModule.recurring,'scheduled'))['linkedGoalId'],
   null);
  expect(await sourceDefault('scheduled'),'wallet');
  expect((await only(WaffraFinanceModule.goals,'target'))['saved'],0.0);
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-M11 clearing only one schedule default deletes its stale account link',()async{
  await modules.save(WaffraFinanceModule.recurring,due('one'));
  await modules.save(WaffraFinanceModule.recurring,due('two'));
  await modules.save(WaffraFinanceModule.recurring,due('one',account:null),
   replaceExisting:true);
  expect(await sourceDefault('one'),null);
  expect(await sourceDefault('two'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'one'))['accountId'],null);
  expect(await count('fresh_finance_recurring'),2);
 });

 test('M949-M12 missing goal refuses new due, existing due and account remain',()async{
  await modules.save(WaffraFinanceModule.recurring,due('existing'));
  await expectLater(modules.save(WaffraFinanceModule.recurring,
   due('orphan',linkedGoal:'does-not-exist')),throwsStateError);
  expect(await count('fresh_finance_recurring'),1);
  expect(await sourceDefault('orphan'),null);
  expect(await sourceDefault('existing'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'existing'))['day'],15);
 });

 test('M949-M13 linked due wrong account edit rolls back typed row and default',()async{
  await modules.save(WaffraFinanceModule.goals,goal('owner'));
  await modules.save(WaffraFinanceModule.recurring,
   due('rent',linkedGoal:'owner'));
  await expectLater(modules.save(WaffraFinanceModule.recurring,
   due('rent',account:'wallet',linkedGoal:'owner',day:29),
   replaceExisting:true),throwsStateError);
  expect(await sourceDefault('rent'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'rent'))['day'],15);
  final sql=await db.customSelect(
   "SELECT due_day FROM fresh_finance_recurring WHERE recurring_id='rent'")
   .getSingle();
  expect(sql.read<int>('due_day'),15);
 });

 test('M949-M14 invalid changed date cannot partially replace recurring account default',()async{
  await modules.save(WaffraFinanceModule.recurring,due('rent'));
  await expectLater(modules.save(WaffraFinanceModule.recurring,
   due('rent',account:'wallet',start:'invalid-time'),replaceExisting:true),
   throwsArgumentError);
  expect(await sourceDefault('rent'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'rent'))['startAt'],
   '2026-11-15T10:00:00');
 });

 test('M949-M15 half-halalah recurring edit cannot change old monthly money amount',()async{
  await modules.save(WaffraFinanceModule.recurring,due('rent'));
  await expectLater(modules.save(WaffraFinanceModule.recurring,
   due('rent',account:'wallet',amount:25.005),replaceExisting:true),
   throwsArgumentError);
  expect(await sourceDefault('rent'),'bank');
  expect((await only(WaffraFinanceModule.recurring,'rent'))['amount'],25.0);
  final sql=await db.customSelect(
   "SELECT amount_minor FROM fresh_finance_recurring WHERE recurring_id='rent'")
   .getSingle();
  expect(sql.read<int>('amount_minor'),2500);
 });

 test('M949-M16 paused recurring date change persists but posts no transaction',()async{
  await modules.save(WaffraFinanceModule.recurring,due('rent'));
  await modules.save(WaffraFinanceModule.recurring,due('rent',
   active:false,day:31,start:'2027-12-31T10:00:00'),replaceExisting:true);
  final saved=await only(WaffraFinanceModule.recurring,'rent');
  expect(saved['active'],false);
  expect(saved['day'],31);
  expect(saved['startAt'],'2027-12-31T10:00:00');
  expect(await sourceDefault('rent'),'bank');
  expect(await count('fresh_finance_entries'),0);
 });

 test('M949-M17 missing ID update in one module preserves all three siblings',()async{
  await modules.save(WaffraFinanceModule.categories,cat('food'));
  await modules.save(WaffraFinanceModule.goals,goal('saving'));
  await modules.save(WaffraFinanceModule.recurring,due('rent'));
  await expectLater(modules.save(WaffraFinanceModule.goals,
   goal('not-created'),replaceExisting:true),throwsStateError);
  await expectLater(modules.save(WaffraFinanceModule.recurring,
   due('not-created'),replaceExisting:true),throwsStateError);
  expect((await modules.list(WaffraFinanceModule.categories)).length,1);
  expect((await modules.list(WaffraFinanceModule.goals)).single['id'],'saving');
  expect((await modules.list(WaffraFinanceModule.recurring)).single['id'],'rent');
  expect(await sourceDefault('rent'),'bank');
 });
}

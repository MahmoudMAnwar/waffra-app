
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_verified_goal_funding_writer.dart';

/// M641 / #562: real encrypted projection, balances, account identity and
/// rollback. Goal wallet is not an income/expense and must not double count.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory temp;
 late WaffraEncryptedStore db;
 WaffraAtomicFinanceSnapshot snapshot()=>
  WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
 WaffraEncryptedFinanceUiPatch ui()=>WaffraEncryptedFinanceUiPatch(
  snapshot:snapshot(),writerDirectory:temp,experimentalEnabled:true);
 const goal=<String,Object?>{
  'id':'car','name':'Car','target':1000.0,'saved':100.0,
  'active':true,'dueDate':'2026-12-15T00:00:00',
  'accountId':'rajhi',
 };
 const due=<String,Object?>{
  'id':'car-due','title':'Car due','amount':1000.0,'income':false,
  'category':'Home / Rent','day':15,'active':true,
  'startAt':'2026-12-15T00:00:00','linkedGoalId':'car',
  'accountId':'rajhi',
 };
 Future<void> post(Map<String,Object?> g,Map<String,Object?> r)async{
  final baseline=await snapshot().read();
  await ui().saveScreenChanges(
   screenBaseline:baseline.values,
   replacementValues:{
    'waffra_goals_v24':jsonEncode([g]),
    'waffra_recurring_v24':jsonEncode([r]),
   },
   changedKeys:const {'waffra_goals_v24','waffra_recurring_v24'});
 }
 Future<int> balance()async{
  final rows=await WaffraAccountsRepository(
   db:db,experimentalEnabled:true).balances();
  return rows.singleWhere((x)=>x.id=='rajhi').balanceMinor;
 }
 setUp(()async{
  temp=await Directory.systemTemp.createTemp('m641-linked-goal-account-');
  db=WaffraEncryptedStore.openAt(File(temp.path+'/vault.sqlite'),
   key:'m641-disposable-linked-goal-sqlcipher-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  await snapshot().initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .createAccount(id:'rajhi',name:'راجحي جاري',kind:'bank',
    openingMinor:100000,createdIso:'2026-11-11T10:00:00Z',
    userConfirmed:true);
 });
 tearDown(()async{
  await db.close();
  if(await temp.exists())await temp.delete(recursive:true);
 });

 test('goal/due use same verified account; one save does not debit balance',()async{
  await post(goal,due);
  expect(await balance(),100000);
  final current=await snapshot().read();
  final gs=jsonDecode(current.values['waffra_goals_v24'] as String) as List;
  final rs=jsonDecode(current.values['waffra_recurring_v24'] as String) as List;
  expect((gs.single as Map)['accountId'],'rajhi');
  expect((rs.single as Map)['accountId'],'rajhi');
  final row=await db.customSelect(
   "SELECT source_json FROM fresh_finance_goals WHERE goal_id='car'"
  ).getSingle();
  expect((jsonDecode(row.read<String>('source_json')) as Map)['accountId'],
   'rajhi');
  final defaultRow=await db.customSelect(
   "SELECT account_id FROM fresh_finance_recurring_account_defaults "
   "WHERE recurring_id='car-due'"
  ).getSingle();
  expect(defaultRow.read<String>('account_id'),'rajhi');
 });

 test('linked goal funding credits wallet, debits bank once, no expense',()async{
  await post(goal,due);
  final before=await snapshot().read();
  final writer=WaffraVerifiedGoalFundingWriter(
   store:db,snapshot:snapshot(),experimentalEnabled:true);
  final saved=await writer.fund(
   expectedGeneration:before.generation,expectedDigest:before.digest,
   goalId:'car',amountMinor:25000,movementId:'goal-fund-m641-1',
   occurredIso:'2026-11-11T12:00:00Z',
   sourceAccountId:'rajhi',userConfirmed:true);
  expect(saved,isTrue);
  expect(await balance(),75000);
  final updated=await snapshot().read();
  final goals=jsonDecode(updated.values['waffra_goals_v24'] as String) as List;
  expect((goals.single as Map)['saved'],350.0);
  expect((goals.single as Map)['accountId'],'rajhi');
  final count=await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle();
  expect(count.read<int>('n'),0);
  await expectLater(writer.fund(
   expectedGeneration:updated.generation,expectedDigest:updated.digest,
   goalId:'car',amountMinor:25000,movementId:'goal-fund-m641-1',
   occurredIso:'2026-11-11T12:00:00Z',
   sourceAccountId:'rajhi',userConfirmed:true),throwsA(isA<StateError>()));
  expect(await balance(),75000);
 });

 test('missing account or mismatched goal/due account rolls back',()async{
  final before=await snapshot().read();
  await expectLater(post({...goal,'accountId':'missing'},
   {...due,'accountId':'missing'}),throwsA(isA<StateError>()));
  expect((await snapshot().read()).generation,before.generation);
  await expectLater(post(goal,{...due,'accountId':null}),
   throwsA(isA<StateError>()));
  expect((await snapshot().read()).generation,before.generation);
  expect(await balance(),100000);
  final goals=await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_goals').getSingle();
  expect(goals.read<int>('n'),0);
 });
}

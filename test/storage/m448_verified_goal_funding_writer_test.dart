import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_account_context_schema.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_verified_goal_funding_writer.dart';

void main(){
 late Directory dir;
 late WaffraEncryptedStore db;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraVerifiedGoalFundingWriter writer;
 const now='2026-11-04T13:00:00Z';
 setUp(()async{
  dir=await Directory.systemTemp.createTemp('m448-goal-writer-');
  db=WaffraEncryptedStore.openAt(File('${dir.path}/vault.sqlite'),
   key:'disposable-m448-goal-transfer-sqlcipher-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true,
  ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
  snapshot=WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
  await snapshot.initializeEmpty();
  await WaffraAccountsSchema.install(db);
  await WaffraAccountContextSchema.install(db);
  await WaffraAccountsRepository(db:db,experimentalEnabled:true)
   .createAccount(id:'rajhi',name:'Bank',kind:'bank',
    openingMinor:100000,createdIso:now,userConfirmed:true);
  const goalId='travel';
  final source=<String,Object?>{
   'id':goalId,'name':'Travel','target':1000.0,'saved':100.0,
   'active':true,
  };
  await db.customStatement(
   'INSERT INTO fresh_finance_goals '
   '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
   [goalId,'Travel',100000,10000,jsonEncode(source)]);
  await snapshot.commit(expectedGeneration:0,fullFinanceSnapshot:{
   'waffra_goals_v24':jsonEncode([source]),
  });
  writer=WaffraVerifiedGoalFundingWriter(
   store:db,snapshot:snapshot,experimentalEnabled:true);
 });
 tearDown(()async{
  await db.close();
  if(await dir.exists())await dir.delete(recursive:true);
 });

 Future<Map<String,int>> balances()async=>
  {for(final a in await WaffraAccountsRepository(
    db:db,experimentalEnabled:true).balances())a.id:a.balanceMinor};

 Future<bool> save(String movement,{String? accountId})async{
  final state=await snapshot.read();
  return writer.fund(expectedGeneration:state.generation,
   expectedDigest:state.digest,goalId:'travel',amountMinor:30000,
   movementId:movement,occurredIso:now,
   sourceAccountId:accountId,userConfirmed:true);
 }

 test('one verified source debit and independent wallet contribution',()async{
  expect(await balances(),{'rajhi':100000});
  expect(await save('fund-one',accountId:'rajhi'),true);
  expect(await balances(),{'rajhi':70000});
  final row=await db.customSelect(
   "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='travel'",
  ).getSingle();
  expect(row.read<int>('saved_minor'),40000);
  final progress=await WaffraAccountContextRepository(
   store:db,experimentalEnabled:true).goalProgress(
    goalId:'travel',selectedAccountId:'rajhi');
  expect(progress.totalSavedMinor,40000);
  expect(progress.selectedAccountNetMinor,30000);
  final goals=jsonDecode((await snapshot.read()).values[
   'waffra_goals_v24'] as String) as List;
  expect((goals.single as Map<String,dynamic>)['saved'],400.0);
  final entries=await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_entries').getSingle();
  expect(entries.read<int>('n'),0);
 });

 test('replay or stale source rejects without double withdrawal',()async{
  final before=await snapshot.read();
  await save('fund-same',accountId:'rajhi');
  await expectLater(writer.fund(
   expectedGeneration:before.generation,expectedDigest:before.digest,
   goalId:'travel',amountMinor:30000,movementId:'fund-other',
   occurredIso:now,sourceAccountId:'rajhi',userConfirmed:true,
  ),throwsA(isA<StateError>()));
  await expectLater(save('fund-same',accountId:'rajhi'),
   throwsA(isA<StateError>()));
  expect(await balances(),{'rajhi':70000});
  final movements=await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_goal_wallet_movements').getSingle();
  expect(movements.read<int>('n'),1);
 });

 test('unassigned deposits never debit a bank',()async{
  await save('fund-unassigned');
  expect(await balances(),{'rajhi':100000});
  final progress=await WaffraAccountContextRepository(
   store:db,experimentalEnabled:true).goalProgress(
    goalId:'travel',selectedAccountId:'rajhi');
  expect(progress.totalSavedMinor,40000);
  expect(progress.selectedAccountNetMinor,0);
 });

 test('missing account rolls back wallet, movement and snapshot',()async{
  final prior=await snapshot.read();
  await expectLater(save('fund-invalid',accountId:'unknown'),
   throwsA(isA<StateError>()));
  final after=await snapshot.read();
  expect(after.generation,prior.generation);
  expect(after.digest,prior.digest);
  expect(await balances(),{'rajhi':100000});
  final row=await db.customSelect(
   "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='travel'",
  ).getSingle();
  expect(row.read<int>('saved_minor'),10000);
  final movements=await db.customSelect(
   'SELECT count(*) AS n FROM fresh_finance_goal_wallet_movements').getSingle();
  expect(movements.read<int>('n'),0);
 });
}

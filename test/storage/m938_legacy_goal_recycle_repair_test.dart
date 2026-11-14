import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_module_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M938: synthetic-only historical encrypted goal trash. No real backups.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 late Directory root;
 late WaffraEncryptedStore db;
 late WaffraAtomicFinanceSnapshot snapshot;
 late WaffraEncryptedModuleRecycle recycle;
 const goal=<String,Object?>{
  'id':'m938-old-deleted-goal','name':'Synthetic historical savings',
  'target':13500.0,'saved':9000.0,'active':true,
 };
 final archivedAt=DateTime.now().toUtc().subtract(const Duration(days:2));
 late WaffraFinanceSnapshotState baseline;

 setUp(()async{
  root=await Directory.systemTemp.createTemp('m938-legacy-trash-');
  db=WaffraEncryptedStore.openAt(
   File('${root.path}/isolated.sqlite'),key:'m938-unique-fake-ci-only-key');
  await WaffraFreshEncryptedVaultBootstrap(
   store:db,experimentalEnabled:true).initialize(
    decision:WaffraFirstRunDecision.freshCandidate);
  snapshot=WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
  await snapshot.initializeEmpty();
  baseline=await snapshot.commit(expectedGeneration:0,
   fullFinanceSnapshot:<String,Object?>{
    'entries':'[]','waffra_goals_v24':'[]',
    'waffra_deleted_goals_v1':jsonEncode([
     {'goal':goal,'deletedAt':archivedAt.toIso8601String()},
    ]),
   });
  recycle=WaffraEncryptedModuleRecycle(
   snapshot:snapshot,writerDirectory:root,
   verifySourceUnderLock:()async{},experimentalEnabled:true);
 });

 tearDown(()async{
  await db.close();
  if(await root.exists())await root.delete(recursive:true);
 });

 test('M938 old encrypted archive with missing SQL tombstone is repairable '
      'only by explicit owner consent; zero changes to ledger or digest',()async{
  await expectLater(recycle.pending(WaffraFinanceModule.goals),
   throwsStateError);
  await expectLater(recycle.repairImportedLegacyTrash(
   module:WaffraFinanceModule.goals,baseline:baseline,
   userConfirmed:false),throwsStateError);
  await recycle.repairImportedLegacyTrash(
   module:WaffraFinanceModule.goals,baseline:baseline,userConfirmed:true);
  final after=await snapshot.read();
  expect(after.generation,baseline.generation);
  expect(after.digest,baseline.digest);
  expect(after.values['entries'],'[]');
  final recoverable=await recycle.pending(WaffraFinanceModule.goals);
  expect(recoverable.keys,contains('m938-old-deleted-goal'));
  expect(recoverable.length,1);
  final restored=await recycle.restore(
   module:WaffraFinanceModule.goals,baseline:after,
   entityId:'m938-old-deleted-goal',now:DateTime.now().toUtc());
  expect(restored.restored,isTrue);
  final current=await snapshot.read();
  expect(current.values['entries'],'[]');
  final goals=jsonDecode(current.values['waffra_goals_v24'] as String) as List;
  expect(goals,hasLength(1));
  expect((goals.single as Map)['saved'],0.0);
  expect(await recycle.pending(WaffraFinanceModule.goals),isEmpty);
 });

 test('M938 refuses stale source generation even with explicit consent',()async{
  final changed=await snapshot.commit(
   expectedGeneration:baseline.generation,
   fullFinanceSnapshot:{...baseline.values,'waffra_custom_goals_v1':<String>[]});
  expect(changed.generation,greaterThan(baseline.generation));
  await expectLater(recycle.repairImportedLegacyTrash(
   module:WaffraFinanceModule.goals,baseline:baseline,
   userConfirmed:true),throwsStateError);
 });

 test('M938 partial SQL tombstone must never be silently repaired',()async{
  await expectLater(recycle.pending(WaffraFinanceModule.goals),
   throwsStateError);
  await db.customStatement(
   'INSERT INTO fresh_finance_module_recycle('
   'module_name,entity_id,source_json,source_sha256,original_index,'
   'deleted_at_ms,expires_at_ms) VALUES(?,?,?,?,?,?,?)',[
    'goals','partial-witness','{}','bad-digest',0,
    archivedAt.millisecondsSinceEpoch,
    archivedAt.add(const Duration(days:30)).millisecondsSinceEpoch,
   ]);
  await expectLater(recycle.repairImportedLegacyTrash(
   module:WaffraFinanceModule.goals,baseline:baseline,
   userConfirmed:true),throwsStateError);
  final same=await snapshot.read();
  expect(same.generation,baseline.generation);
  expect(same.digest,baseline.digest);
 });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M452: SQLCipher verifies that a linked goal edit never commits only
/// its goal half when the recurring projection rejects the same batch.
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore db;
  const goal=<String,Object?>{
    'id':'trip','name':'Trip','target':500,'saved':100,'active':true,
    'dueDate':'2026-12-15T00:00:00',
  };
  const due=<String,Object?>{
    'id':'trip-due','title':'Trip due','amount':500,'income':false,
    'category':'Home / Rent','day':15,
    'startAt':'2026-12-15T00:00:00','linkedGoalId':'trip','active':true,
  };
  WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(
    store:db,experimentalEnabled:true);
  WaffraEncryptedFinanceUiPatch ui()=>WaffraEncryptedFinanceUiPatch(
    snapshot:snapshot(),writerDirectory:temp,experimentalEnabled:true);
  Future<void> post(Map<String,Object?> updatedGoal,Map<String,Object?> updatedDue)async{
    final before=await snapshot().read();
    await ui().saveScreenChanges(screenBaseline:before.values,
      replacementValues:{
        'waffra_goals_v24':jsonEncode([updatedGoal]),
        'waffra_recurring_v24':jsonEncode([updatedDue]),
      },changedKeys:const {'waffra_goals_v24','waffra_recurring_v24'});
  }
  setUp(()async{
    temp=await Directory.systemTemp.createTemp('waffra-m452-goal-due-');
    db=WaffraEncryptedStore.openAt(File(temp.path+'/test.sqlite'),
     key:'m452-atomic-goal-due-test-only');
    await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
      .initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(()async{
    await db.close();
    if(await temp.exists())await temp.delete(recursive:true);
  });
  test('new goal and its due persist together in one encrypted generation',()async{
    await post(goal,due);
    final snap=await snapshot().read();
    expect(snap.generation,1);
    expect((jsonDecode(snap.values['waffra_goals_v24'] as String) as List).length,1);
    expect((jsonDecode(snap.values['waffra_recurring_v24'] as String) as List).length,1);
    final g=await db.customSelect("SELECT target_minor FROM fresh_finance_goals WHERE goal_id='trip'").getSingle();
    final r=await db.customSelect("SELECT amount_minor FROM fresh_finance_recurring WHERE recurring_id='trip-due'").getSingle();
    expect(g.read<int>('target_minor'),50000);
    expect(r.read<int>('amount_minor'),50000);
  });
  test('corrupted recurring typed witness rolls back simultaneous goal edit',()async{
    await post(goal,due);
    final before=await snapshot().read();
    await db.customStatement("UPDATE fresh_finance_recurring SET amount_minor=999 WHERE recurring_id='trip-due'");
    await expectLater(post({...goal,'target':600},{...due,'amount':600}),throwsStateError);
    final after=await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    final saved=await db.customSelect("SELECT target_minor FROM fresh_finance_goals WHERE goal_id='trip'").getSingle();
    expect(saved.read<int>('target_minor'),50000);
  });
  test('goal and linked due update together when source is verified',()async{
    await post(goal,due);
    await post({...goal,'target':600,'name':'Trip extended'},
      {...due,'amount':600,'title':'Trip extended due'});
    final after=await snapshot().read();
    expect(after.generation,2);
    final g=await db.customSelect("SELECT target_minor FROM fresh_finance_goals WHERE goal_id='trip'").getSingle();
    final r=await db.customSelect("SELECT amount_minor FROM fresh_finance_recurring WHERE recurring_id='trip-due'").getSingle();
    expect(g.read<int>('target_minor'),60000);
    expect(r.read<int>('amount_minor'),60000);
  });
}

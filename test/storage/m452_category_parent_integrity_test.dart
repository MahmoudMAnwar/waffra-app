import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore db;
  const parent=<String,Object?>{'id':'root','name':'Home','parentId':'','income':false,'budget':0};
  const child=<String,Object?>{'id':'child','name':'Home / Rent','parentId':'root','income':false,'budget':0};
  WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(store:db,experimentalEnabled:true);
  WaffraEncryptedFinanceUiPatch editor()=>WaffraEncryptedFinanceUiPatch(snapshot:snapshot(),writerDirectory:root,experimentalEnabled:true);
  Future<void> save(List<Map<String,Object?>> categories)async{
    final baseline=await snapshot().read();
    await editor().saveScreenChanges(screenBaseline:baseline.values,
      replacementValues:{'waffra_categories_v24':jsonEncode(categories)},
      changedKeys:const {'waffra_categories_v24'});
  }
  setUp(()async{
    root=await Directory.systemTemp.createTemp('m452-parent-integrity-');
    db=WaffraEncryptedStore.openAt(File(root.path+'/category.sqlite'),key:'m452-disposable-sqlcipher-only');
    await WaffraFreshEncryptedVaultBootstrap(store:db,experimentalEnabled:true)
      .initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(()async{
    await db.close();
    if(await root.exists())await root.delete(recursive:true);
  });
  test('valid main and child are committed to typed encrypted SQL',()async{
    await save([parent,child]);
    final rows=await db.customSelect('SELECT category_id,parent_id FROM fresh_finance_categories ORDER BY category_id').get();
    expect(rows.length,2);
    expect(rows.first.read<String>('parent_id'),'root');
  });
  test('orphan and wrong-type or nested category fail with full rollback',()async{
    await save([parent,child]);
    final before=await snapshot().read();
    for(final invalid in <List<Map<String,Object?>>>[
      [parent,{...child,'parentId':'gone'}],
      [parent,{...child,'income':true}],
      [parent,child,{...child,'id':'grandchild','parentId':'child'}],
    ]){
      await expectLater(save(invalid),throwsStateError);
      final after=await snapshot().read();
      expect(after.digest,before.digest);
      expect(after.generation,before.generation);
    }
  });
  test('SQL itself blocks direct orphan and reparent of a populated root',()async{
    await save([parent,child]);
    await expectLater(db.customStatement("UPDATE fresh_finance_categories SET parent_id='missing' WHERE category_id='child'"),throwsA(isA<Exception>()));
    await expectLater(db.customStatement("UPDATE fresh_finance_categories SET parent_id='child' WHERE category_id='root'"),throwsA(isA<Exception>()));
    await expectLater(db.customStatement("DELETE FROM fresh_finance_categories WHERE category_id='root'"),throwsA(isA<Exception>()));
  });
}

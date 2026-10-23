import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M136: synthetic SQLCipher projection-loss incidents only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const category=<String,Object?>{
    'id':'food','name':'Food','parentId':'','income':false,'budget':250,
  };
  const recurring=<String,Object?>{
    'id':'rent','title':'Rent','amount':900,'income':false,'day':5,
    'startAt':'2026-10-22T12:00:00',
  };
  late Directory root;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot()=>WaffraAtomicFinanceSnapshot(
    store:vault,experimentalEnabled:true,
  );
  WaffraEncryptedFinanceUiPatch editor()=>WaffraEncryptedFinanceUiPatch(
    snapshot:snapshot(),writerDirectory:root,experimentalEnabled:true,
  );

  setUp(() async {
    root=await Directory.systemTemp.createTemp('waffra-m136-disposable-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m136-disposable-encrypted-vault',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store:vault,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final before=await snapshot().read();
    final after=await editor().saveScreenChanges(
      screenBaseline:before.values,
      replacementValues:{
        'waffra_categories_v24':jsonEncode([category]),
        'waffra_recurring_v24':jsonEncode([recurring]),
      },
      changedKeys:const {'waffra_categories_v24','waffra_recurring_v24'},
    );
    expect(after.generation,1);
  });

  tearDown(() async {
    await vault.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  Future<void> rejectMissingRow(String sql) async {
    final before=await snapshot().read();
    await vault.customStatement(sql);
    final catBefore=await vault.customSelect(
      'SELECT category_id,budget_minor,source_json FROM fresh_finance_categories',
    ).get();
    final recBefore=await vault.customSelect(
      'SELECT recurring_id,amount_minor,source_json FROM fresh_finance_recurring',
    ).get();
    await expectLater(
      editor().saveScreenChanges(
        screenBaseline:before.values,
        replacementValues:{
          'waffra_categories_v24':jsonEncode([{...category,'budget':300}]),
          'waffra_recurring_v24':jsonEncode([{...recurring,'amount':950}]),
        },
        changedKeys:const {'waffra_categories_v24','waffra_recurring_v24'},
      ),
      throwsStateError,
    );
    final after=await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    expect(after.values,before.values);
    final catAfter=await vault.customSelect(
      'SELECT category_id,budget_minor,source_json FROM fresh_finance_categories',
    ).get();
    final recAfter=await vault.customSelect(
      'SELECT recurring_id,amount_minor,source_json FROM fresh_finance_recurring',
    ).get();
    expect(catAfter.map((r)=>r.data).toList(),catBefore.map((r)=>r.data).toList());
    expect(recAfter.map((r)=>r.data).toList(),recBefore.map((r)=>r.data).toList());
  }

  test('missing category SQL row prevents all concurrent finance edits',() async {
    await rejectMissingRow(
      "DELETE FROM fresh_finance_categories WHERE category_id='food'",
    );
  });

  test('missing recurring SQL row prevents all concurrent finance edits',() async {
    await rejectMissingRow(
      "DELETE FROM fresh_finance_recurring WHERE recurring_id='rent'",
    );
  });

  test('both module SQL rows missing cannot be silently recreated',() async {
    final before=await snapshot().read();
    await vault.customStatement('DELETE FROM fresh_finance_categories');
    await vault.customStatement('DELETE FROM fresh_finance_recurring');
    await expectLater(
      editor().saveScreenChanges(
        screenBaseline:before.values,
        replacementValues:{
          'waffra_categories_v24':jsonEncode([{...category,'budget':300}]),
          'waffra_recurring_v24':jsonEncode([{...recurring,'amount':950}]),
        },
        changedKeys:const {'waffra_categories_v24','waffra_recurring_v24'},
      ),
      throwsStateError,
    );
    final after=await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    expect(after.values,before.values);
    final cat=await vault.customSelect('SELECT category_id FROM fresh_finance_categories').get();
    final rec=await vault.customSelect('SELECT recurring_id FROM fresh_finance_recurring').get();
    expect(cat,isEmpty);
    expect(rec,isEmpty);
  });
}

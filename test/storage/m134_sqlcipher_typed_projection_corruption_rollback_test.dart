import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M134: corrupt only synthetic SQL rows, never production storage.
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
  WaffraFreshModulesRepository modules()=>WaffraFreshModulesRepository(
    store:vault,experimentalEnabled:true,
  );

  setUp(() async {
    root=await Directory.systemTemp.createTemp('waffra-m134-synthetic-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m134-test-key-only-2026',
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

  Future<void> rejectAfterCorruption(String sql) async {
    final before=await snapshot().read();
    await vault.customStatement(sql);
    final corruptCategory=await vault.customSelect(
      "SELECT name,parent_id,is_income,budget_minor,source_json "
      "FROM fresh_finance_categories WHERE category_id='food'",
    ).getSingle();
    final corruptRecurring=await vault.customSelect(
      "SELECT amount_minor,is_income,due_day,source_json "
      "FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();
    final categoryRow=corruptCategory.data;
    final recurringRow=corruptRecurring.data;
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
    final categoryAfter=await vault.customSelect(
      "SELECT name,parent_id,is_income,budget_minor,source_json "
      "FROM fresh_finance_categories WHERE category_id='food'",
    ).getSingle();
    final recurringAfter=await vault.customSelect(
      "SELECT amount_minor,is_income,due_day,source_json "
      "FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();
    expect(categoryAfter.data,categoryRow);
    expect(recurringAfter.data,recurringRow);
    expect(await modules().list(WaffraFinanceModule.categories),[category]);
    expect(await modules().list(WaffraFinanceModule.recurring),[recurring]);
  }

  test('forged category name rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_categories SET name='Forged' WHERE category_id='food'",
    );
  });
  test('forged category parent rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_categories SET parent_id='unknown' WHERE category_id='food'",
    );
  });
  test('forged category income flag rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_categories SET is_income=1 WHERE category_id='food'",
    );
  });
  test('forged recurring due day rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_recurring SET due_day=31 WHERE recurring_id='rent'",
    );
  });
  test('forged recurring amount rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_recurring SET amount_minor=1 WHERE recurring_id='rent'",
    );
  });
  test('forged recurring income flag rejects all concurrent edits',() async {
    await rejectAfterCorruption(
      "UPDATE fresh_finance_recurring SET is_income=1 WHERE recurring_id='rent'",
    );
  });
}

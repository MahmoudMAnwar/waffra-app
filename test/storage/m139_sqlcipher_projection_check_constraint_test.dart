import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M139: SQLite CHECK constraints reject forged numeric and enum projections.
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
    root=await Directory.systemTemp.createTemp('waffra-m139-disposable-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m139-disposable-qa-key-32-bytes0',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store:vault,experimentalEnabled:true,
    ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final empty=await snapshot().read();
    final seeded=await editor().saveScreenChanges(
      screenBaseline:empty.values,
      replacementValues:{
        'waffra_categories_v24':jsonEncode([category]),
        'waffra_recurring_v24':jsonEncode([recurring]),
      },
      changedKeys:const {'waffra_categories_v24','waffra_recurring_v24'},
    );
    expect(seeded.generation,1);
  });

  tearDown(() async {
    await vault.close();
    if(await root.exists())await root.delete(recursive:true);
  });

  // Invalid typed values must fail at SQLite CHECK before the encrypted
  // snapshot or any projection is changed; a valid atomic save must still work.
  Future<void> expectCheckConstraintProtectsState(String sql) async {
    final before=await snapshot().read();
    final categoryRows=await vault.customSelect(
      'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
      'FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    final recurringRows=await vault.customSelect(
      'SELECT recurring_id,amount_minor,is_income,due_day,source_json '
      'FROM fresh_finance_recurring ORDER BY recurring_id',
    ).get();

    await expectLater(
      vault.customStatement(sql),
      throwsA(predicate((Object error) =>
        error.toString().contains('CHECK constraint failed'))),
    );

    final after=await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    expect(after.values,before.values);
    final catAfter=await vault.customSelect(
      'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
      'FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    final recAfter=await vault.customSelect(
      'SELECT recurring_id,amount_minor,is_income,due_day,source_json '
      'FROM fresh_finance_recurring ORDER BY recurring_id',
    ).get();
    expect(catAfter.map((r)=>r.data).toList(),categoryRows.map((r)=>r.data).toList());
    expect(recAfter.map((r)=>r.data).toList(),recurringRows.map((r)=>r.data).toList());

    // The rejected invalid statement must not poison subsequent legitimate
    // atomic updates of both modules.
    final saved=await editor().saveScreenChanges(
      screenBaseline:before.values,
      replacementValues:{
        'waffra_categories_v24':jsonEncode([{...category,'budget':310}]),
        'waffra_recurring_v24':jsonEncode([{...recurring,'amount':950}]),
      },
      changedKeys:const {'waffra_categories_v24','waffra_recurring_v24'},
    );
    expect(saved.generation,before.generation+1);
    final verified=await snapshot().read();
    expect(verified.generation,saved.generation);
    expect(verified.digest,saved.digest);
    expect(verified.values,saved.values);
  }

  test('negative category budget is rejected by SQL CHECK',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_categories SET budget_minor=-1 WHERE category_id='food'",
    );
  });

  test('category income flag outside boolean range is rejected',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_categories SET is_income=2 WHERE category_id='food'",
    );
  });

  test('negative recurring amount is rejected by SQL CHECK',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET amount_minor=-1 WHERE recurring_id='rent'",
    );
  });

  test('recurring due day zero is rejected by SQL CHECK',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET due_day=0 WHERE recurring_id='rent'",
    );
  });

  test('recurring due day 32 is rejected by SQL CHECK',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET due_day=32 WHERE recurring_id='rent'",
    );
  });

  test('recurring income flag outside boolean range is rejected',() async {
    await expectCheckConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET is_income=-1 WHERE recurring_id='rent'",
    );
  });
}

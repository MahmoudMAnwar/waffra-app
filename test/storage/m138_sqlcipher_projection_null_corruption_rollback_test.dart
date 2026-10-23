import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M138: NULL typed-value corruption checks in a disposable SQLCipher vault.
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
    root=await Directory.systemTemp.createTemp('waffra-m138-disposable-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m138-disposable-qa-key-32-bytes-000',
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

  // SQLite's NOT NULL constraints reject the attempted corruption before a
  // malformed typed row can exist. Verify that first-line protection and that
  // the encrypted finance snapshot remains writable and internally consistent.
  Future<void> expectNotNullConstraintProtectsState(String sql) async {
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
        error.toString().contains('NOT NULL constraint failed'))),
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

  test('NULL category name is rejected by SQL NOT NULL constraint',() async {
    await expectNotNullConstraintProtectsState(
      "UPDATE fresh_finance_categories SET name=NULL WHERE category_id='food'",
    );
  });

  test('NULL category budget is rejected by SQL NOT NULL constraint',() async {
    await expectNotNullConstraintProtectsState(
      "UPDATE fresh_finance_categories SET budget_minor=NULL WHERE category_id='food'",
    );
  });

  test('NULL recurring amount is rejected by SQL NOT NULL constraint',() async {
    await expectNotNullConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET amount_minor=NULL WHERE recurring_id='rent'",
    );
  });

  test('NULL recurring due day is rejected by SQL NOT NULL constraint',() async {
    await expectNotNullConstraintProtectsState(
      "UPDATE fresh_finance_recurring SET due_day=NULL WHERE recurring_id='rent'",
    );
  });
}

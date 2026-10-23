import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Synthetic, disposable encrypted database only; no live finance records.
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
    root=await Directory.systemTemp.createTemp('waffra-m135-disposable-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m135-disposable-qa-key-32-bytes-',
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

  Future<void> rejectWithoutRepair(String sql) async {
    final before=await snapshot().read();
    await vault.customStatement(sql);
    final categoryBefore=await vault.customSelect(
      "SELECT name,parent_id,is_income,budget_minor,source_json "
      "FROM fresh_finance_categories WHERE category_id='food'",
    ).getSingle();
    final recurringBefore=await vault.customSelect(
      "SELECT amount_minor,is_income,due_day,source_json "
      "FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline:before.values,
        replacementValues:{
          'waffra_categories_v24':jsonEncode([{...category,'budget':310}]),
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
    expect(categoryAfter.data,categoryBefore.data);
    expect(recurringAfter.data,recurringBefore.data);
  }

  test('category JSON witness modified without typed SQL change',() async {
    await rejectWithoutRepair(
      "UPDATE fresh_finance_categories SET source_json='"
      '{"id":"food","name":"Forged","parentId":"","income":false,"budget":250}'
      "' WHERE category_id='food'",
    );
  });
  test('recurring JSON witness modified without typed SQL change',() async {
    await rejectWithoutRepair(
      "UPDATE fresh_finance_recurring SET source_json='"
      '{"id":"rent","title":"Forged","amount":900,"income":false,'
      '"day":5,"startAt":"2026-10-22T12:00:00"}'
      "' WHERE recurring_id='rent'",
    );
  });
  test('category witness identity substitution is rejected',() async {
    await rejectWithoutRepair(
      "UPDATE fresh_finance_categories SET source_json='"
      '{"id":"forged","name":"Food","parentId":"","income":false,"budget":250}'
      "' WHERE category_id='food'",
    );
  });
  test('recurring witness identity substitution is rejected',() async {
    await rejectWithoutRepair(
      "UPDATE fresh_finance_recurring SET source_json='"
      '{"id":"forged","title":"Rent","amount":900,"income":false,'
      '"day":5,"startAt":"2026-10-22T12:00:00"}'
      "' WHERE recurring_id='rent'",
    );
  });
}

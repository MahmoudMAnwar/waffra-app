import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// Extra-row intrusion checks in a temporary SQLCipher vault only.
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
    root=await Directory.systemTemp.createTemp('waffra-m137-disposable-');
    vault=WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),key:'m137-disposable-qa-key-32-bytes0',
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

  Future<void> expectNoPartialCommit(String sql) async {
    final before=await snapshot().read();
    await vault.customStatement(sql);
    final categoryRows=await vault.customSelect(
      'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
      'FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    final recurringRows=await vault.customSelect(
      'SELECT recurring_id,amount_minor,is_income,due_day,source_json '
      'FROM fresh_finance_recurring ORDER BY recurring_id',
    ).get();
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
  }

  test('unrecognized extra category SQL row fails closed',() async {
    await expectNoPartialCommit(
      "INSERT INTO fresh_finance_categories "
      "(category_id,name,parent_id,is_income,budget_minor,source_json) "
      "VALUES ('injected','Injected','',0,0,"
      "'{\"id\":\"injected\",\"name\":\"Injected\",\"parentId\":\"\","
      "\"income\":false,\"budget\":0}')",
    );
  });

  test('unrecognized extra recurring SQL row fails closed',() async {
    await expectNoPartialCommit(
      "INSERT INTO fresh_finance_recurring "
      "(recurring_id,amount_minor,is_income,due_day,source_json) "
      "VALUES ('injected',100,0,1,"
      "'{\"id\":\"injected\",\"title\":\"Injected\",\"amount\":1,"
      "\"income\":false,\"day\":1,"
      "\"startAt\":\"2026-10-22T12:00:00\"}')",
    );
  });

  test('unexpected rows in both projections cannot be overwritten',() async {
    await vault.customStatement(
      "INSERT INTO fresh_finance_categories "
      "(category_id,name,parent_id,is_income,budget_minor,source_json) "
      "VALUES ('injected','Injected','',0,0,'{}')",
    );
    await expectNoPartialCommit(
      "INSERT INTO fresh_finance_recurring "
      "(recurring_id,amount_minor,is_income,due_day,source_json) "
      "VALUES ('injected',100,0,1,'{}')",
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M128: synthetic SQLCipher only; production storage remains disabled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = <String, Object?>{
    'id': 'food',
    'name': 'Food',
    'parentId': '',
    'income': false,
    'budget': 250,
  };

  late Directory root;
  late WaffraEncryptedStore store;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: store,
        experimentalEnabled: true,
      );

  WaffraEncryptedFinanceUiPatch editor() => WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: root,
        experimentalEnabled: true,
      );

  WaffraFreshModulesRepository modules() => WaffraFreshModulesRepository(
        store: store,
        experimentalEnabled: true,
      );

  Future<void> expectUnchanged(WaffraFinanceSnapshotState before) async {
    final after = await snapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values, before.values);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m128-category-');
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm128-disposable-category-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final empty = await snapshot().read();
    final seeded = await editor().saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {'waffra_categories_v24': jsonEncode([category])},
      changedKeys: const {'waffra_categories_v24'},
    );
    expect(seeded.generation, 1);
    expect(await modules().list(WaffraFinanceModule.categories), [category]);
  });

  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('typed category budget mismatch rejects Home save without repair',
      () async {
    final before = await snapshot().read();
    // Source JSON still says 250; typed budget is forged independently.
    await store.customStatement(
      "UPDATE fresh_finance_categories SET budget_minor=999 "
      "WHERE category_id='food'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([
            {...category, 'budget': 300},
          ]),
        },
        changedKeys: const {'waffra_categories_v24'},
      ),
      throwsStateError,
    );

    await expectUnchanged(before);
    expect(await modules().list(WaffraFinanceModule.categories), [category]);
    final row = await store.customSelect(
      "SELECT budget_minor FROM fresh_finance_categories "
      "WHERE category_id='food'",
    ).getSingle();
    expect(row.read<int>('budget_minor'), 999);
  });

  test('missing category projection refuses update plus create', () async {
    final before = await snapshot().read();
    await store.customStatement(
      "DELETE FROM fresh_finance_categories WHERE category_id='food'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([
            {...category, 'budget': 300},
            {...category, 'id': 'travel', 'name': 'Travel'},
          ]),
        },
        changedKeys: const {'waffra_categories_v24'},
      ),
      throwsStateError,
    );

    await expectUnchanged(before);
    expect(await modules().list(WaffraFinanceModule.categories), isEmpty);
  });
}

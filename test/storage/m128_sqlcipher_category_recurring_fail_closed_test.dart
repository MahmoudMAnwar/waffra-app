import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('M128 typed category mismatch rejects Home save atomically', () async {
    final root = await Directory.systemTemp.createTemp('waffra-m128-');
    final store = WaffraEncryptedStore.openAt(
      File('${root.path}/test.sqlite'), key: 'm128-disposable-only',
    );
    try {
      await WaffraFreshEncryptedVaultBootstrap(
        store: store, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: store, experimentalEnabled: true,
      );
      await snapshot.initializeEmpty();
      final editor = WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot, writerDirectory: root, experimentalEnabled: true,
      );
      const category = <String, Object?>{
        'id': 'food', 'name': 'Food', 'parentId': '',
        'income': false, 'budget': 250,
      };
      final empty = await snapshot.read();
      await editor.saveScreenChanges(
        screenBaseline: empty.values,
        replacementValues: {'waffra_categories_v24': jsonEncode([category])},
        changedKeys: const {'waffra_categories_v24'},
      );
      final before = await snapshot.read();
      await store.customStatement(
        "UPDATE fresh_finance_categories SET budget_minor=999 "
        "WHERE category_id='food'",
      );
      await expectLater(editor.saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([{...category, 'budget': 300}]),
        },
        changedKeys: const {'waffra_categories_v24'},
      ), throwsStateError);
      final after = await snapshot.read();
      expect(after.generation, before.generation);
      expect(after.digest, before.digest);
      expect(after.values, before.values);
      final modules = WaffraFreshModulesRepository(
        store: store, experimentalEnabled: true,
      );
      expect(await modules.list(WaffraFinanceModule.categories), [category]);
    } finally {
      await store.close();
      await root.delete(recursive: true);
    }
  });
}

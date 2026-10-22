import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore store;
  const key = 'm114-only-disposable-encrypted-finance-key';

  WaffraAtomicFinanceSnapshot get snapshot => WaffraAtomicFinanceSnapshot(
    store: store, experimentalEnabled: true,
  );
  WaffraEncryptedFinanceUiPatch get editor => WaffraEncryptedFinanceUiPatch(
    snapshot: snapshot,
    writerDirectory: root,
    experimentalEnabled: true,
  );
  WaffraFreshModulesRepository get modules => WaffraFreshModulesRepository(
    store: store, experimentalEnabled: true,
  );

  const category = <String, Object?>{
    'id': 'food', 'name': 'Food', 'income': false,
    'budget': 250, 'parentId': '',
  };
  const goal = <String, Object?>{
    'id': 'trip', 'name': 'Trip', 'target': 5000, 'saved': 0,
  };
  const recurring = <String, Object?>{
    'id': 'rent', 'title': 'Rent', 'amount': 1000,
    'income': false, 'day': 1, 'startAt': '2026-10-22T12:00:00',
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m114-');
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/m114.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot.initializeEmpty();
  });
  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('three module create operations commit SQL and snapshot in one generation',
      () async {
    final before = await snapshot.read();
    final next = await editor.saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_goals_v24': jsonEncode([goal]),
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
      changedKeys: const {
        'waffra_categories_v24', 'waffra_goals_v24', 'waffra_recurring_v24',
      },
    );
    expect(next.generation, 1);
    for (final module in WaffraFinanceModule.values) {
      expect(await modules.list(module), hasLength(1));
    }
    expect((await modules.list(WaffraFinanceModule.categories)).single['budget'], 250);
    expect((await modules.list(WaffraFinanceModule.goals)).single['target'], 5000);
  });

  test('widget append survives concurrent goal creation and both remain durable',
      () async {
    final before = await snapshot.read();
    final writer = WaffraUnifiedFinanceWriter(
      writerDirectory: root,
      snapshot: snapshot,
      experimentalEnabled: true,
    );
    await writer.appendTransactions(
      records: [{
        'id': 'widget', 'title': 'Widget', 'category': 'Food',
        'amount': 2.25, 'income': false, 'date': '2026-10-22T13:00:00',
        'receiptPath': null,
      }],
      messageHashes: [null], userConfirmed: true,
    );
    final updated = await editor.saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {'waffra_goals_v24': jsonEncode([goal])},
      changedKeys: const {'waffra_goals_v24'},
    );
    expect(updated.generation, 2);
    expect(updated.values['entries'], contains('"id":"widget"'));
    expect(await modules.list(WaffraFinanceModule.goals), hasLength(1));
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/m114.sqlite'), key: key,
    );
    expect((await snapshot.read()).values['entries'], contains('"id":"widget"'));
    expect(await modules.list(WaffraFinanceModule.goals), hasLength(1));
  });

  test('removing active module entity fails and retains both projections',
      () async {
    final empty = await snapshot.read();
    await editor.saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {'waffra_goals_v24': jsonEncode([goal])},
      changedKeys: const {'waffra_goals_v24'},
    );
    final baseline = await snapshot.read();
    await expectLater(editor.saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: const {'waffra_goals_v24': '[]'},
      changedKeys: const {'waffra_goals_v24'},
    ), throwsStateError);
    expect((await snapshot.read()).generation, 1);
    expect(await modules.list(WaffraFinanceModule.goals), hasLength(1));
  });

  test('mismatched old SQL module refuses UI overwrite', () async {
    final before = await snapshot.read();
    await editor.saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {'waffra_categories_v24': jsonEncode([category])},
      changedKeys: const {'waffra_categories_v24'},
    );
    await store.customStatement(
      "UPDATE fresh_finance_categories SET source_json='{}' WHERE category_id='food'",
    );
    final stale = await snapshot.read();
    await expectLater(editor.saveScreenChanges(
      screenBaseline: stale.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 300}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    ), throwsStateError);
    expect((await snapshot.read()).generation, 1);
  });

  test('invalid second module write rolls back successful first projection',
      () async {
    final before = await snapshot.read();
    await expectLater(editor.saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_recurring_v24': jsonEncode([{...recurring, 'day': 32}]),
      },
      changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
    ), throwsA(anyOf(isA<ArgumentError>(), isA<StateError>())));
    expect((await snapshot.read()).generation, 0);
    expect(await modules.list(WaffraFinanceModule.categories), isEmpty);
    expect(await modules.list(WaffraFinanceModule.recurring), isEmpty);
  });
}

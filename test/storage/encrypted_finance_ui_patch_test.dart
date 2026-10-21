import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore store;

  WaffraAtomicFinanceSnapshot snapshot() =>
      WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);

  WaffraEncryptedFinanceUiPatch screen({bool enabled = true}) =>
      WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: root,
        experimentalEnabled: enabled,
      );

  WaffraUnifiedFinanceWriter widgetWriter() => WaffraUnifiedFinanceWriter(
    writerDirectory: root, snapshot: snapshot(), experimentalEnabled: true,
  );

  Future<void> setupVault() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  }

  Map<String, Object?> tx(String id) => {
    'id': id, 'title': 'Widget purchase', 'category': 'Shopping',
    'amount': 12.5, 'income': false, 'receiptPath': null,
    'date': '2026-10-21T16:00:00',
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-ui-patch-test-');
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/ui.sqlite'),
      key: 'disposable-ui-screen-finance-test-32',
    );
  });
  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('UI goal edits never erase newly saved Android widget transactions',
      () async {
    await setupVault();
    final baseline = await screen().readForScreen();
    final goal = jsonEncode([
      {'id': 'trip', 'name': 'رحلة', 'target': 5000.0, 'saved': 0.0},
    ]);
    await widgetWriter().appendTransactions(
      records: [tx('widget-one')],
      messageHashes: [null], userConfirmed: true,
    );
    final result = await screen().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {'waffra_goals_v24': goal},
      changedKeys: {'waffra_goals_v24'},
    );
    expect(result.generation, 2);
    expect(result.values['waffra_goals_v24'], goal);
    expect((jsonDecode(result.values['entries'] as String) as List)
        .single['id'], 'widget-one');
  });

  test('older goal tab cannot overwrite a newer goal edit', () async {
    await setupVault();
    final oldScreen = await screen().readForScreen();
    await screen().saveScreenChanges(
      screenBaseline: oldScreen.values,
      replacementValues: {'waffra_goals_v24': '[{"id":"new","name":"New","target":100,"saved":0}]'},
      changedKeys: {'waffra_goals_v24'},
    );
    await expectLater(screen().saveScreenChanges(
      screenBaseline: oldScreen.values,
      replacementValues: {'waffra_goals_v24': '[{"id":"old","name":"Old","target":100,"saved":0}]'},
      changedKeys: {'waffra_goals_v24'},
    ), throwsA(isA<StateError>()));
    expect((await snapshot().read()).values['waffra_goals_v24'],
        '[{"id":"new","name":"New","target":100,"saved":0}]');
  });

  test('an older dashboard cannot overwrite the Widget new entry list',
      () async {
    await setupVault();
    final prior = await screen().readForScreen();
    await widgetWriter().appendTransactions(
      records: [tx('widget-updated')],
      messageHashes: [null], userConfirmed: true,
    );
    await expectLater(screen().saveScreenChanges(
      screenBaseline: prior.values,
      replacementValues: {'entries': '[]'},
      changedKeys: {'entries'},
    ), throwsA(isA<StateError>()));
    final newEntries = jsonDecode(
      (await snapshot().read()).values['entries'] as String,
    ) as List;
    expect(newEntries.single['id'], 'widget-updated');
  });

  test('changing category and goal together has one atomic generation',
      () async {
    await setupVault();
    final original = await screen().readForScreen();
    final result = await screen().saveScreenChanges(
      screenBaseline: original.values,
      replacementValues: {
        'waffra_categories_v24': '[{"id":"cat","name":"مأكولات","income":false,"budget":0}]',
        'waffra_goals_v24': '[{"id":"goal","name":"رحلة","target":1000,"saved":0}]',
      },
      changedKeys: {'waffra_categories_v24', 'waffra_goals_v24'},
    );
    expect(result.generation, 1);
    expect(result.values['waffra_goals_v24'], contains('رحلة'));
    expect(result.values['waffra_categories_v24'], contains('مأكولات'));
  });

  test('invalid field data refuses all changes with unchanged previous state',
      () async {
    await setupVault();
    final old = await screen().readForScreen();
    await expectLater(screen().saveScreenChanges(
      screenBaseline: old.values,
      replacementValues: {
        'waffra_goals_v24': '[{"id":"bad","name":"Goal","target":-10,"saved":0}]',
        'waffra_categories_v24': '[]',
      },
      changedKeys: {'waffra_goals_v24', 'waffra_categories_v24'},
    ), throwsA(isA<StateError>()));
    final state = await snapshot().read();
    expect(state.generation, 0);
    expect(state.values, isEmpty);
  });

  test('no edit can silently remove a finance preference or unknown key',
      () async {
    await setupVault();
    final baseline = await screen().readForScreen();
    for (final changed in [
      {'waffra_goals_v24'},
      {'not-a-finance-key'},
      <String>{},
    ]) {
      await expectLater(screen().saveScreenChanges(
        screenBaseline: baseline.values,
        replacementValues: const {},
        changedKeys: changed,
      ), throwsA(isA<ArgumentError>()));
    }
    expect((await snapshot().read()).generation, 0);
  });

  test('disabled UI patch never opens encrypted finance', () async {
    await setupVault();
    await expectLater(screen(enabled: false).readForScreen(),
        throwsA(isA<StateError>()));
    await expectLater(screen(enabled: false).saveScreenChanges(
      screenBaseline: const {}, replacementValues: const {'entries': '[]'},
      changedKeys: const {'entries'},
    ), throwsA(isA<StateError>()));
    expect((await snapshot().read()).generation, 0);
  });

  test('reopening encrypted vault keeps unrelated finance changes', () async {
    await setupVault();
    final baseline = await screen().readForScreen();
    await screen().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {'waffra_monthly_budget_v1': 1500.0},
      changedKeys: {'waffra_monthly_budget_v1'},
    );
    await widgetWriter().appendTransactions(
      records: [tx('purchase')], messageHashes: [null],
      userConfirmed: true,
    );
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/ui.sqlite'),
      key: 'disposable-ui-screen-finance-test-32',
    );
    final after = await screen().readForScreen();
    expect(after.generation, 2);
    expect(after.values['waffra_monthly_budget_v1'], 1500.0);
    expect((jsonDecode(after.values['entries'] as String) as List)
        .single['id'], 'purchase');
  });
}

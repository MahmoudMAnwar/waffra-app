import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M143: Confirm captures a stable copy before any asynchronous lock wait.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const category = <String, Object?>{
    'id': 'food', 'name': 'Food', 'parentId': '', 'income': false, 'budget': 250,
  };
  late Directory root;
  late WaffraEncryptedStore store;
  WaffraAtomicFinanceSnapshot snapshot() =>
      WaffraAtomicFinanceSnapshot(store: store, experimentalEnabled: true);
  WaffraEncryptedFinanceUiPatch editor([Future<void> Function()? witness]) =>
      WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(), writerDirectory: root,
        experimentalEnabled: true, verifySourceUnderLock: witness,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m143-disposable-');
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/test.sqlite'), key: 'm143-test-disposable-key',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final before = await snapshot().read();
    await editor().saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {'waffra_categories_v24': jsonEncode([category])},
      changedKeys: const {'waffra_categories_v24'},
    );
  });
  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<int> budget() async => (await store.customSelect(
    "SELECT budget_minor FROM fresh_finance_categories WHERE category_id='food'",
  ).getSingle()).read<int>('budget_minor');

  test('M143: mutation of form map, baseline and changed keys after Confirm is ignored', () async {
    final before = await snapshot().read();
    final entered = Completer<void>();
    final release = Completer<void>();
    final baseline = Map<String, Object?>.from(before.values);
    final values = <String, Object?>{
      'waffra_categories_v24': jsonEncode([{...category, 'budget': 310}]),
    };
    final keys = <String>{'waffra_categories_v24'};
    final saving = editor(() async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: baseline, replacementValues: values, changedKeys: keys,
    );
    await entered.future;
    baseline['waffra_categories_v24'] = jsonEncode([]);
    values['waffra_categories_v24'] =
        jsonEncode([{...category, 'budget': 999}]);
    keys.clear();
    keys.add('waffra_goals_v24');
    release.complete();
    final result = await saving;
    expect(result.generation, before.generation + 1);
    expect(await budget(), 31000);
    expect(jsonDecode(result.values['waffra_categories_v24'] as String),
        [{...category, 'budget': 310}]);
    expect(result.values.containsKey('waffra_goals_v24'), isFalse);
  });

  test('M143: changed-key expansion cannot inject a new goal while waiting', () async {
    final before = await snapshot().read();
    final entered = Completer<void>();
    final release = Completer<void>();
    final keys = <String>{'waffra_categories_v24'};
    final values = <String, Object?>{
      'waffra_categories_v24': jsonEncode([{...category, 'budget': 325}]),
      'waffra_goals_v24': jsonEncode([
        {'id': 'unapproved', 'name': 'Unapproved', 'target': 500, 'saved': 0},
      ]),
    };
    final saving = editor(() async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: before.values, replacementValues: values,
      changedKeys: keys,
    );
    await entered.future;
    keys.add('waffra_goals_v24');
    values['waffra_goals_v24'] = jsonEncode([
      {'id': 'injected', 'name': 'Injected', 'target': 900, 'saved': 0},
    ]);
    release.complete();
    final result = await saving;
    expect(result.generation, before.generation + 1);
    expect(await budget(), 32500);
    expect(result.values.containsKey('waffra_goals_v24'), isFalse);
    expect(await store.customSelect('SELECT goal_id FROM fresh_finance_goals').get(),
        isEmpty);
  });

  test('M143: changed baseline cannot disguise an intervening conflicting save', () async {
    final before = await snapshot().read();
    final entered = Completer<void>();
    final release = Completer<void>();
    final baseline = Map<String, Object?>.from(before.values);
    final pending = editor(() async {
      entered.complete();
      await release.future;
    }).saveScreenChanges(
      screenBaseline: baseline,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 700}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    await entered.future;
    // Simulated independent writer. Direct snapshot commit deliberately does
    // not touch typed projections; this test verifies the pending edit does not.
    final latest = await snapshot().read();
    final accepted = await snapshot().commit(
      expectedGeneration: latest.generation,
      fullFinanceSnapshot: {
        ...latest.values,
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 360}]),
      },
    );
    baseline['waffra_categories_v24'] =
        accepted.values['waffra_categories_v24'];
    release.complete();
    await expectLater(pending, throwsStateError);
    final after = await snapshot().read();
    expect(after.generation, accepted.generation);
    expect(after.digest, accepted.digest);
    expect(after.values, accepted.values);
    expect(await budget(), 25000);
  });
}

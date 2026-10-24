import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_module_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraFreshModulesRepository repository;
  late WaffraEncryptedModuleRecycle recycle;
  var sourceAllowed = true;
  final now = DateTime.utc(2026, 10, 24, 15);

  const activeKeys = <WaffraFinanceModule, String>{
    WaffraFinanceModule.categories: 'waffra_categories_v24',
    WaffraFinanceModule.goals: 'waffra_goals_v24',
    WaffraFinanceModule.recurring: 'waffra_recurring_v24',
  };
  const trashKeys = <WaffraFinanceModule, String>{
    WaffraFinanceModule.categories: 'waffra_deleted_categories_v1',
    WaffraFinanceModule.goals: 'waffra_deleted_goals_v1',
    WaffraFinanceModule.recurring: 'waffra_deleted_recurring_v1',
  };
  const root = <String, Object?>{
    'id': 'root', 'name': 'Main', 'parentId': '', 'income': false,
    'budget': 200.0, 'icon': 'house', 'color': 15,
  };
  const child = <String, Object?>{
    'id': 'child', 'name': 'Sub', 'parentId': 'root', 'income': false,
    'budget': 100.0, 'icon': 'coffee', 'color': 17,
  };
  const goal = <String, Object?>{
    'id': 'car-goal', 'name': 'Car', 'target': 1500.0, 'saved': 500.0,
  };
  const recurring = <String, Object?>{
    'id': 'rent-24', 'title': 'Rent', 'amount': 240.0,
    'income': false, 'day': 24, 'startAt': '2026-01-01T00:00:00',
    'category': 'Housing', 'active': true,
  };

  Future<void> seed(
    WaffraFinanceModule module,
    List<Map<String, Object?>> data,
  ) async {
    for (final entry in data) {
      await repository.save(module, entry);
    }
    final baseline = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: baseline.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...baseline.values,
        activeKeys[module]!: jsonEncode(data),
        // Financial history must never be cleared by module deletion.
        'entries': '[]',
        'waffra_sms_hashes_v1':
            <String>['aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'],
      },
    );
  }

  Future<List<Map<String, dynamic>>> live(
    WaffraFinanceModule module,
  ) async => (jsonDecode(
    (await snapshot.read()).values[activeKeys[module]] as String,
  ) as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  Future<List<Map<String, dynamic>>> deleted(
    WaffraFinanceModule module,
  ) async => (jsonDecode(
    (await snapshot.read()).values[trashKeys[module]] as String? ?? '[]',
  ) as List<dynamic>)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();

  Future<WaffraEncryptedModuleRecycleResult> remove(
    WaffraFinanceModule module,
    String entityId, {
    bool confirmed = true,
    WaffraFinanceSnapshotState? baseline,
  }) async => recycle.softDelete(
    module: module,
    baseline: baseline ?? await snapshot.read(),
    entityId: entityId, now: now, userConfirmed: confirmed,
  );

  Future<WaffraEncryptedModuleRecycleResult> restore(
    WaffraFinanceModule module,
    String entityId, {
    WaffraFinanceSnapshotState? baseline,
    DateTime? at,
  }) async => recycle.restore(
    module: module,
    baseline: baseline ?? await snapshot.read(),
    entityId: entityId,
    now: at ?? now.add(const Duration(hours: 1)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('m185-module-trash-');
    store = WaffraEncryptedStore.openAt(
      File('${temp.path}/synthetic.sqlite'),
      key: 'm185-disposable-test-vault-not-live-user-data',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    repository = WaffraFreshModulesRepository(
      store: store, experimentalEnabled: true,
    );
    sourceAllowed = true;
    recycle = WaffraEncryptedModuleRecycle(
      snapshot: snapshot, writerDirectory: temp,
      verifySourceUnderLock: () async {
        if (!sourceAllowed) {
          throw StateError('Synthetic source marker is no longer certified.');
        }
      },
      experimentalEnabled: true,
    );
  });

  tearDown(() async {
    await store.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M185 encrypted goal recycle preserves transactions, restores saved zero',
      () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final before = await snapshot.read();
    final removed = await remove(WaffraFinanceModule.goals, 'car-goal');
    expect(removed.restored, isFalse);
    expect(removed.expiresAtMs,
        now.add(const Duration(days: 30)).millisecondsSinceEpoch);
    expect(await live(WaffraFinanceModule.goals), isEmpty);
    expect((await deleted(WaffraFinanceModule.goals)).single['goal'], goal);
    expect(await repository.list(WaffraFinanceModule.goals), isEmpty);
    expect((await snapshot.read()).values['entries'], before.values['entries']);
    expect((await snapshot.read()).values['waffra_sms_hashes_v1'],
        before.values['waffra_sms_hashes_v1']);
    expect((await recycle.pending(WaffraFinanceModule.goals)).keys,
        contains('car-goal'));

    final result = await restore(WaffraFinanceModule.goals, 'car-goal');
    expect(result.restored, isTrue);
    expect((await live(WaffraFinanceModule.goals)).single['saved'], 0.0);
    expect((await repository.list(WaffraFinanceModule.goals)).single['saved'], 0.0);
    expect(await deleted(WaffraFinanceModule.goals), isEmpty);
    expect(await recycle.pending(WaffraFinanceModule.goals), isEmpty);
  });

  test('M185 category parent deletion blocks live children', () async {
    await seed(WaffraFinanceModule.categories, [root, child]);
    final original = await snapshot.read();
    await expectLater(
      remove(WaffraFinanceModule.categories, 'root'),
      throwsStateError,
    );
    expect((await snapshot.read()).digest, original.digest);
    await remove(WaffraFinanceModule.categories, 'child');
    expect((await live(WaffraFinanceModule.categories)).single['id'], 'root');
    await remove(WaffraFinanceModule.categories, 'root');
    expect(await live(WaffraFinanceModule.categories), isEmpty);
    await expectLater(restore(WaffraFinanceModule.categories, 'child'),
        throwsStateError);
    await restore(WaffraFinanceModule.categories, 'root');
    await restore(WaffraFinanceModule.categories, 'child');
    final restored = await live(WaffraFinanceModule.categories);
    expect(restored.map((x) => x['id']), ['root', 'child']);
    expect(restored.every((x) => x['budget'] == 0.0), isTrue);
  });

  test('M185 recurring trash protects pending postponements and restores day',
      () async {
    await seed(WaffraFinanceModule.recurring, [recurring]);
    final initial = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: initial.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...initial.values,
        'waffra_recurring_postponed_v1': '{"rec_rent-24_2026_10":"2026-10-28"}',
      },
    );
    await expectLater(remove(WaffraFinanceModule.recurring, 'rent-24'),
        throwsStateError);
    final next = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: next.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...next.values,
        'waffra_recurring_postponed_v1': '{}',
      },
    );
    await remove(WaffraFinanceModule.recurring, 'rent-24');
    await restore(WaffraFinanceModule.recurring, 'rent-24');
    expect((await live(WaffraFinanceModule.recurring)).single['day'], 24);
    expect((await live(WaffraFinanceModule.recurring)).single['active'], false);
    expect((await repository.list(WaffraFinanceModule.recurring)).single['active'], false);
    expect((await repository.list(WaffraFinanceModule.recurring)).length, 1);
  });

  test('M185 stale Home witness blocks delete and restore without partial SQL',
      () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final stale = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: stale.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...stale.values, 'waffra_monthly_budget_v1': 500.0,
      },
    );
    await expectLater(remove(WaffraFinanceModule.goals, 'car-goal',
        baseline: stale), throwsStateError);
    expect((await live(WaffraFinanceModule.goals)).length, 1);
    await remove(WaffraFinanceModule.goals, 'car-goal');
    final old = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: old.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...old.values, 'waffra_monthly_budget_v1': 600.0,
      },
    );
    await expectLater(restore(WaffraFinanceModule.goals, 'car-goal',
        baseline: old), throwsStateError);
    expect(await live(WaffraFinanceModule.goals), isEmpty);
  });

  test('M185 expired or rolled-back restore refuses financial mutation', () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    await remove(WaffraFinanceModule.goals, 'car-goal');
    final after = await snapshot.read();
    for (final date in [
      now.subtract(const Duration(milliseconds: 1)),
      now.add(const Duration(days: 30)),
      now.add(const Duration(days: 31)),
    ]) {
      await expectLater(restore(WaffraFinanceModule.goals, 'car-goal',
          at: date), throwsStateError);
    }
    expect((await snapshot.read()).digest, after.digest);
    expect((await recycle.pending(WaffraFinanceModule.goals)).length, 1);
  });

  test('M185 typed SQL tampering prevents any module recycle', () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final original = await snapshot.read();
    await store.customStatement(
      "UPDATE fresh_finance_goals SET saved_minor=99999 "
      "WHERE goal_id='car-goal'",
    );
    await expectLater(remove(WaffraFinanceModule.goals, 'car-goal'),
        throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
  });

  test('M185 trash checksum tamper cannot restore different budget', () async {
    await seed(WaffraFinanceModule.categories, [root]);
    await remove(WaffraFinanceModule.categories, 'root');
    final before = await snapshot.read();
    await store.customStatement(
      "UPDATE fresh_finance_module_recycle SET source_json=? "
      "WHERE module_name='categories' AND entity_id='root'",
      [jsonEncode({...root, 'budget': 9999.0})],
    );
    await expectLater(restore(WaffraFinanceModule.categories, 'root'),
        throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
  });

  test('M185 missing SQL tombstone rejects any incompatible legacy trash', () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final before = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: before.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...before.values,
        trashKeys[WaffraFinanceModule.goals]!:
            jsonEncode(<Map<String, Object?>>[
          {'goal': goal, 'deletedAt': now.toIso8601String()},
        ]),
      },
    );
    await expectLater(remove(WaffraFinanceModule.goals, 'car-goal'),
        throwsStateError);
    expect((await repository.list(WaffraFinanceModule.goals)).length, 1);
  });

  test('M185 consent and source-mismatch failures never erase a finance entity',
      () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final old = await snapshot.read();
    await expectLater(remove(WaffraFinanceModule.goals, 'car-goal',
        confirmed: false), throwsStateError);
    sourceAllowed = false;
    await expectLater(remove(WaffraFinanceModule.goals, 'car-goal'),
        throwsStateError);
    expect((await snapshot.read()).digest, old.digest);
    expect((await repository.list(WaffraFinanceModule.goals)).length, 1);
  });

  test('M185 encrypted recycle is default-disabled', () async {
    await seed(WaffraFinanceModule.goals, [goal]);
    final disabled = WaffraEncryptedModuleRecycle(
      snapshot: snapshot, writerDirectory: temp,
      verifySourceUnderLock: () async {},
    );
    await expectLater(disabled.softDelete(
      module: WaffraFinanceModule.goals,
      baseline: await snapshot.read(),
      entityId: 'car-goal', now: now, userConfirmed: true,
    ), throwsStateError);
    await expectLater(disabled.pending(WaffraFinanceModule.goals),
        throwsStateError);
  });
}

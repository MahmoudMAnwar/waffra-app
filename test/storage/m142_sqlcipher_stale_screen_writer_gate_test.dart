import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M142: stale UI baselines and cooperating writers cannot silently overwrite
/// new finance data. Disposable SQLCipher vault; never used in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = <String, Object?>{
    'id': 'food', 'name': 'Food', 'parentId': '',
    'income': false, 'budget': 250,
  };
  const recurring = <String, Object?>{
    'id': 'rent', 'title': 'Rent', 'amount': 900,
    'income': false, 'day': 5, 'startAt': '2026-10-22T12:00:00',
  };
  const firstGoal = <String, Object?>{
    'id': 'emergency', 'name': 'Emergency', 'target': 600, 'saved': 0,
  };
  const secondGoal = <String, Object?>{
    'id': 'holiday', 'name': 'Holiday', 'target': 900, 'saved': 0,
  };

  late Directory root;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store: vault, experimentalEnabled: true,
  );

  WaffraEncryptedFinanceUiPatch editor({
    Future<void> Function()? verifySourceUnderLock,
  }) => WaffraEncryptedFinanceUiPatch(
    snapshot: snapshot(), writerDirectory: root,
    experimentalEnabled: true,
    verifySourceUnderLock: verifySourceUnderLock,
  );

  Future<List<Map<String, Object?>>> categoryRows() async {
    final rows = await vault.customSelect(
      'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
      'FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    return rows.map((r) => Map<String, Object?>.from(r.data)).toList();
  }

  Future<List<Map<String, Object?>>> recurringRows() async {
    final rows = await vault.customSelect(
      'SELECT recurring_id,amount_minor,is_income,due_day,source_json '
      'FROM fresh_finance_recurring ORDER BY recurring_id',
    ).get();
    return rows.map((r) => Map<String, Object?>.from(r.data)).toList();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m142-disposable-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm142-disposable-qa-key-32-bytes0',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final initial = await snapshot().read();
    final seeded = await editor().saveScreenChanges(
      screenBaseline: initial.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
      changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
    );
    expect(seeded.generation, 1);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M142: stale category edit rejects entire batch, including fresh recurring edit', () async {
    final baseline = await snapshot().read();
    final committed = await editor().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 310}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    final categoriesAfterFirstSave = await categoryRows();
    final recurringBeforeRejectedSave = await recurringRows();

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: baseline.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([{...category, 'budget': 500}]),
          'waffra_recurring_v24': jsonEncode([{...recurring, 'amount': 950}]),
        },
        changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
      ),
      throwsStateError,
    );

    final after = await snapshot().read();
    expect(after.generation, committed.generation);
    expect(after.digest, committed.digest);
    expect(after.values, committed.values);
    expect(await categoryRows(), categoriesAfterFirstSave);
    expect(await recurringRows(), recurringBeforeRejectedSave);
  });

  test('M142: stale baseline can patch unrelated key without losing intervening edit', () async {
    final baseline = await snapshot().read();
    final first = await editor().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_recurring_v24': jsonEncode([{...recurring, 'amount': 940}]),
      },
      changedKeys: const {'waffra_recurring_v24'},
    );
    final second = await editor().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 360}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    expect(first.generation, baseline.generation + 1);
    expect(second.generation, baseline.generation + 2);
    final stored = await snapshot().read();
    expect(stored.generation, second.generation);
    expect(stored.digest, second.digest);
    expect((await categoryRows()).single['budget_minor'], 36000);
    expect((await recurringRows()).single['amount_minor'], 94000);
    expect(
      jsonDecode(stored.values['waffra_recurring_v24'] as String),
      [{...recurring, 'amount': 940}],
    );
  });

  test('M142: competing same-key saves serialize and only one can commit', () async {
    final baseline = await snapshot().read();
    Future<Object> race(int budget) async {
      try {
        return await editor().saveScreenChanges(
          screenBaseline: baseline.values,
          replacementValues: {
            'waffra_categories_v24': jsonEncode([
              {...category, 'budget': budget},
            ]),
          },
          changedKeys: const {'waffra_categories_v24'},
        );
      } catch (error) {
        return error;
      }
    }

    final outcomes = await Future.wait<Object>([race(311), race(312)]);
    final successes = outcomes.whereType<WaffraFinanceSnapshotState>().toList();
    final rejections = outcomes.whereType<StateError>().toList();
    expect(successes, hasLength(1));
    expect(rejections, hasLength(1));
    final stored = await snapshot().read();
    expect(stored.generation, baseline.generation + 1);
    expect(stored.digest, successes.single.digest);
    expect(stored.values, successes.single.values);
    expect([31100, 31200], contains((await categoryRows()).single['budget_minor']));
    expect((await recurringRows()).single['amount_minor'], 90000);
  });

  test('M142: two stale goal creates cannot erase the earlier goal', () async {
    final baseline = await snapshot().read();
    final first = await editor().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {'waffra_goals_v24': jsonEncode([firstGoal])},
      changedKeys: const {'waffra_goals_v24'},
    );
    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: baseline.values,
        replacementValues: {'waffra_goals_v24': jsonEncode([secondGoal])},
        changedKeys: const {'waffra_goals_v24'},
      ),
      throwsStateError,
    );
    final rows = await vault.customSelect(
      'SELECT goal_id,target_minor,saved_minor,source_json '
      'FROM fresh_finance_goals ORDER BY goal_id',
    ).get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('goal_id'), 'emergency');
    expect(rows.single.read<int>('target_minor'), 60000);
    final after = await snapshot().read();
    expect(after.generation, first.generation);
    expect(after.digest, first.digest);
    expect(jsonDecode(after.values['waffra_goals_v24'] as String), [firstGoal]);
  });

  test('M142: failed authoritative source witness blocks all finance edits', () async {
    final baseline = await snapshot().read();
    final categoriesBefore = await categoryRows();
    final recurringBefore = await recurringRows();
    await expectLater(
      editor(verifySourceUnderLock: () async {
        throw StateError('m142-source-witness-denied');
      }).saveScreenChanges(
        screenBaseline: baseline.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([{...category, 'budget': 400}]),
          'waffra_recurring_v24': jsonEncode([{...recurring, 'amount': 1100}]),
        },
        changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
      ),
      throwsA(predicate((Object error) =>
        error.toString().contains('m142-source-witness-denied'))),
    );
    final after = await snapshot().read();
    expect(after.generation, baseline.generation);
    expect(after.digest, baseline.digest);
    expect(after.values, baseline.values);
    expect(await categoryRows(), categoriesBefore);
    expect(await recurringRows(), recurringBefore);
    final recovered = await editor().saveScreenChanges(
      screenBaseline: baseline.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([{...category, 'budget': 410}]),
      },
      changedKeys: const {'waffra_categories_v24'},
    );
    expect(recovered.generation, baseline.generation + 1);
    expect((await categoryRows()).single['budget_minor'], 41000);
  });
}

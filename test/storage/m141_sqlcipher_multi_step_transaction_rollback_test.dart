import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M141: a late failure must roll back ALL earlier successful writes within
/// one disposable SQLCipher transaction, including snapshot generation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = <String, Object?>{
    'id': 'food',
    'name': 'Food',
    'parentId': '',
    'income': false,
    'budget': 250,
  };
  const recurring = <String, Object?>{
    'id': 'rent',
    'title': 'Rent',
    'amount': 900,
    'income': false,
    'day': 5,
    'startAt': '2026-10-22T12:00:00',
  };

  late Directory root;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: vault,
        experimentalEnabled: true,
      );

  WaffraEncryptedFinanceUiPatch editor() => WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: root,
        experimentalEnabled: true,
      );

  Future<List<Map<String, Object?>>> categoryRows() async {
    final rows = await vault.customSelect(
      'SELECT category_id,name,parent_id,is_income,budget_minor,source_json '
      'FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  Future<List<Map<String, Object?>>> recurringRows() async {
    final rows = await vault.customSelect(
      'SELECT recurring_id,amount_minor,is_income,due_day,source_json '
      'FROM fresh_finance_recurring ORDER BY recurring_id',
    ).get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m141-disposable-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm141-disposable-qa-key-32-bytes0',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final empty = await snapshot().read();
    final seeded = await editor().saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
      changedKeys: const {
        'waffra_categories_v24',
        'waffra_recurring_v24',
      },
    );
    expect(seeded.generation, 1);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> expectFullRollback(
    Future<void> Function() mutateInsideTransaction, {
    required String expectedError,
  }) async {
    final before = await snapshot().read();
    final beforeCategories = await categoryRows();
    final beforeRecurring = await recurringRows();

    await expectLater(
      vault.transaction(mutateInsideTransaction),
      throwsA(predicate((Object error) =>
          error.toString().contains(expectedError))),
    );

    final after = await snapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values, before.values);
    expect(await categoryRows(), beforeCategories);
    expect(await recurringRows(), beforeRecurring);

    // Any rejected transaction must leave the writer usable and let the next
    // authorized multi-module edit commit exactly once.
    final accepted = await editor().saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([
          {...category, 'budget': 310}
        ]),
        'waffra_recurring_v24': jsonEncode([
          {...recurring, 'amount': 950}
        ]),
      },
      changedKeys: const {
        'waffra_categories_v24',
        'waffra_recurring_v24',
      },
    );
    expect(accepted.generation, before.generation + 1);
    final committed = await snapshot().read();
    expect(committed.digest, accepted.digest);
    expect(committed.values, accepted.values);
    expect((await categoryRows()).single['budget_minor'], 31000);
    expect((await recurringRows()).single['amount_minor'], 95000);
  }

  test('M141: valid category edit rolls back after invalid recurring day', () async {
    await expectFullRollback(() async {
      await vault.customStatement(
        "UPDATE fresh_finance_categories SET budget_minor=99100 WHERE category_id='food'",
      );
      expect((await categoryRows()).single['budget_minor'], 99100);
      await vault.customStatement(
        "UPDATE fresh_finance_recurring SET due_day=32 WHERE recurring_id='rent'",
      );
    }, expectedError: 'CHECK constraint failed');
  });

  test('M141: valid recurring edit rolls back after invalid category budget', () async {
    await expectFullRollback(() async {
      await vault.customStatement(
        "UPDATE fresh_finance_recurring SET amount_minor=105000 WHERE recurring_id='rent'",
      );
      expect((await recurringRows()).single['amount_minor'], 105000);
      await vault.customStatement(
        "UPDATE fresh_finance_categories SET budget_minor=-1 WHERE category_id='food'",
      );
    }, expectedError: 'CHECK constraint failed');
  });

  test('M141: snapshot generation mutation rolls back with late SQL failure', () async {
    await expectFullRollback(() async {
      await vault.customStatement(
        'UPDATE fresh_finance_snapshot_state SET generation=generation+1 '
        'WHERE singleton=1',
      );
      await vault.customStatement(
        "UPDATE fresh_finance_recurring SET due_day=0 WHERE recurring_id='rent'",
      );
    }, expectedError: 'CHECK constraint failed');
  });

  test('M141: injected application failure reverts two valid SQL edits', () async {
    await expectFullRollback(() async {
      await vault.customStatement(
        "UPDATE fresh_finance_categories SET budget_minor=99100 WHERE category_id='food'",
      );
      await vault.customStatement(
        "UPDATE fresh_finance_recurring SET amount_minor=105000 WHERE recurring_id='rent'",
      );
      expect((await categoryRows()).single['budget_minor'], 99100);
      expect((await recurringRows()).single['amount_minor'], 105000);
      throw StateError('m141-injected-application-failure');
    }, expectedError: 'm141-injected-application-failure');
  });
}

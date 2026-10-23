import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M133: disposable encrypted vault only. Never contacts production data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = <String, Object?>{
    'id': 'groceries',
    'name': 'Groceries',
    'parentId': '',
    'income': false,
    'budget': 250,
  };
  const recurring = <String, Object?>{
    'id': 'monthly',
    'title': 'Monthly',
    'amount': 75,
    'income': false,
    'day': 3,
    'startAt': '2026-10-22T12:00:00',
  };

  late Directory root;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      );

  WaffraEncryptedFinanceUiPatch editor() => WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: root,
        experimentalEnabled: true,
      );

  WaffraFreshModulesRepository modules() => WaffraFreshModulesRepository(
        store: vault, experimentalEnabled: true,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m133-isolated-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm133-disposable-test-key-2026',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final empty = await snapshot().read();
    final first = await editor().saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([category]),
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
      changedKeys: const {'waffra_categories_v24','waffra_recurring_v24'},
    );
    expect(first.generation,1);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> expectRollback(Map<String,String> edits) async {
    final before = await snapshot().read();
    final beforeCategories = await modules().list(WaffraFinanceModule.categories);
    final beforeRecurring = await modules().list(WaffraFinanceModule.recurring);
    final catTyped = await vault.customSelect(
      "SELECT budget_minor FROM fresh_finance_categories WHERE category_id='groceries'",
    ).getSingle();
    final recTyped = await vault.customSelect(
      "SELECT amount_minor,due_day FROM fresh_finance_recurring WHERE recurring_id='monthly'",
    ).getSingle();

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: edits,
        changedKeys: edits.keys.toSet(),
      ),
      throwsStateError,
    );

    final after = await snapshot().read();
    expect(after.generation,before.generation);
    expect(after.digest,before.digest);
    expect(after.values,before.values);
    expect(await modules().list(WaffraFinanceModule.categories),beforeCategories);
    expect(await modules().list(WaffraFinanceModule.recurring),beforeRecurring);
    final catAfter = await vault.customSelect(
      "SELECT budget_minor FROM fresh_finance_categories WHERE category_id='groceries'",
    ).getSingle();
    final recAfter = await vault.customSelect(
      "SELECT amount_minor,due_day FROM fresh_finance_recurring WHERE recurring_id='monthly'",
    ).getSingle();
    expect(catAfter.read<int>('budget_minor'),catTyped.read<int>('budget_minor'));
    expect(recAfter.read<int>('amount_minor'),recTyped.read<int>('amount_minor'));
    expect(recAfter.read<int>('due_day'),recTyped.read<int>('due_day'));
  }

  test('fractional halalas in category prevent a valid recurring edit', () async {
    await expectRollback({
      'waffra_recurring_v24': jsonEncode([{...recurring,'amount':95}]),
      'waffra_categories_v24': jsonEncode([{...category,'budget':250.001}]),
    });
  });

  test('invalid recurring due day prevents a valid category budget edit', () async {
    await expectRollback({
      'waffra_categories_v24': jsonEncode([{...category,'budget':350}]),
      'waffra_recurring_v24': jsonEncode([{...recurring,'day':32}]),
    });
  });

  test('invalid recurring date cannot partially save category edits', () async {
    await expectRollback({
      'waffra_categories_v24': jsonEncode([{...category,'budget':350}]),
      'waffra_recurring_v24': jsonEncode([{...recurring,'startAt':'not-a-date'}]),
    });
  });

  test('nonnumeric category budget cannot partially save recurring edits', () async {
    await expectRollback({
      'waffra_recurring_v24': jsonEncode([{...recurring,'amount':95}]),
      'waffra_categories_v24': jsonEncode([{...category,'budget':'not-money'}]),
    });
  });

  test('valid category and recurring edits commit together in one generation', () async {
    final before=await snapshot().read();
    final editedCategory={...category,'budget':330};
    final editedRecurring={...recurring,'amount':87,'day':20};
    final after=await editor().saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([editedCategory]),
        'waffra_recurring_v24': jsonEncode([editedRecurring]),
      },
      changedKeys: const {'waffra_categories_v24','waffra_recurring_v24'},
    );
    expect(after.generation,before.generation+1);
    expect(after.digest,isNot(before.digest));
    expect(await modules().list(WaffraFinanceModule.categories),[editedCategory]);
    expect(await modules().list(WaffraFinanceModule.recurring),[editedRecurring]);
    final typedCategory=await vault.customSelect(
      "SELECT budget_minor FROM fresh_finance_categories WHERE category_id='groceries'",
    ).getSingle();
    final typedRecurring=await vault.customSelect(
      "SELECT amount_minor,due_day FROM fresh_finance_recurring WHERE recurring_id='monthly'",
    ).getSingle();
    expect(typedCategory.read<int>('budget_minor'),33000);
    expect(typedRecurring.read<int>('amount_minor'),8700);
    expect(typedRecurring.read<int>('due_day'),20);
  });
}

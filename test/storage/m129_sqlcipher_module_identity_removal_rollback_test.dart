import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M129: synthetic test vault only; never modifies live user data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const initialCategory = <String, Object?>{
    'id': 'groceries',
    'name': 'Groceries',
    'parentId': '',
    'income': false,
    'budget': 250,
  };
  const initialRecurring = <String, Object?>{
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
        store: vault,
        experimentalEnabled: true,
      );
  WaffraEncryptedFinanceUiPatch editor() => WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: root,
        experimentalEnabled: true,
      );
  WaffraFreshModulesRepository modules() => WaffraFreshModulesRepository(
        store: vault,
        experimentalEnabled: true,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m129-disposable-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/test.sqlite'),
      key: 'm129-disposable-test-key-only-2026',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final before = await snapshot().read();
    final after = await editor().saveScreenChanges(
      screenBaseline: before.values,
      replacementValues: {
        'waffra_categories_v24': jsonEncode([initialCategory]),
        'waffra_recurring_v24': jsonEncode([initialRecurring]),
      },
      changedKeys: const {'waffra_categories_v24', 'waffra_recurring_v24'},
    );
    expect(after.generation, 1);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> rejectedWithoutMutation(
    Map<String, String> replacement,
  ) async {
    final before = await snapshot().read();
    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: replacement,
        changedKeys: replacement.keys.toSet(),
      ),
      throwsStateError,
    );
    final after = await snapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values, before.values);
    expect(await modules().list(WaffraFinanceModule.categories),
        [initialCategory]);
    expect(await modules().list(WaffraFinanceModule.recurring),
        [initialRecurring]);
  }

  test('category deletion requires verified recycle retention', () async {
    await rejectedWithoutMutation({
      'waffra_categories_v24': jsonEncode(<Object>[]),
    });
  });

  test('recurring deletion requires verified recycle retention', () async {
    await rejectedWithoutMutation({
      'waffra_recurring_v24': jsonEncode(<Object>[]),
    });
  });

  test('duplicate category identity cannot mutate recurring in same batch',
      () async {
    await rejectedWithoutMutation({
      'waffra_recurring_v24': jsonEncode([
        {...initialRecurring, 'amount': 95},
      ]),
      'waffra_categories_v24': jsonEncode([
        initialCategory,
        {...initialCategory, 'name': 'Forged duplicate'},
      ]),
    });
  });

  test('empty recurring identity cannot mutate category in same batch',
      () async {
    await rejectedWithoutMutation({
      'waffra_categories_v24': jsonEncode([
        {...initialCategory, 'budget': 350},
      ]),
      'waffra_recurring_v24': jsonEncode([
        initialRecurring,
        {...initialRecurring, 'id': ''},
      ]),
    });
  });

  test('malformed category list fails closed without data loss', () async {
    await rejectedWithoutMutation({
      'waffra_categories_v24': jsonEncode({'id': 'wrong-type'}),
    });
  });
}

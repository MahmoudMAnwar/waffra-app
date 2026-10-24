import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M128: all mutations and tampering happen in a fresh disposable test vault.
/// A corrupted typed SQL projection must never be silently repaired by Home.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recurring = <String, Object?>{
    'id': 'rent',
    'title': 'Rent',
    'amount': 1000,
    'income': false,
    'day': 1,
    'startAt': '2026-10-22T12:00:00',
  };
  const category = <String, Object?>{
    'id': 'food',
    'name': 'Food',
    'income': false,
    'budget': 250,
    'parentId': '',
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

  Future<void> expectUnchanged(WaffraFinanceSnapshotState before) async {
    final after = await snapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values, before.values);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m128-recurring-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm128-disposable-sqlcipher-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    final empty = await snapshot().read();
    final seeded = await editor().saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {'waffra_recurring_v24': jsonEncode([recurring])},
      changedKeys: const {'waffra_recurring_v24'},
    );
    expect(seeded.generation, 1);
    expect(await modules().list(WaffraFinanceModule.recurring), [recurring]);
  });

  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('tampered typed due day rejects recurring edit and rolls back category',
      () async {
    final before = await snapshot().read();
    // Leave source_json and canonical snapshot unchanged: only typed SQL
    // differs. Category would be inserted first in the multi-module patch.
    await vault.customStatement(
      "UPDATE fresh_finance_recurring SET due_day=30 "
      "WHERE recurring_id='rent'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_categories_v24': jsonEncode([category]),
          'waffra_recurring_v24': jsonEncode([
            {...recurring, 'day': 2},
          ]),
        },
        changedKeys: const {
          'waffra_categories_v24',
          'waffra_recurring_v24',
        },
      ),
      throwsStateError,
    );

    await expectUnchanged(before);
    expect(await modules().list(WaffraFinanceModule.categories), isEmpty);
    expect(await modules().list(WaffraFinanceModule.recurring), [recurring]);
    final row = await vault.customSelect(
      "SELECT due_day FROM fresh_finance_recurring WHERE recurring_id='rent'",
    ).getSingle();
    expect(row.read<int>('due_day'), 30);
  });

  test('tampered typed amount refuses Home edit without repairing SQL row',
      () async {
    final before = await snapshot().read();
    await vault.customStatement(
      "UPDATE fresh_finance_recurring SET amount_minor=999 "
      "WHERE recurring_id='rent'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_recurring_v24': jsonEncode([
            {...recurring, 'amount': 1100},
          ]),
        },
        changedKeys: const {'waffra_recurring_v24'},
      ),
      throwsStateError,
    );

    await expectUnchanged(before);
    expect(await modules().list(WaffraFinanceModule.recurring), [recurring]);
    final row = await vault.customSelect(
      "SELECT amount_minor FROM fresh_finance_recurring "
      "WHERE recurring_id='rent'",
    ).getSingle();
    expect(row.read<int>('amount_minor'), 999);
  });

  test('missing recurring SQL row blocks update plus create atomically',
      () async {
    final before = await snapshot().read();
    await vault.customStatement(
      "DELETE FROM fresh_finance_recurring WHERE recurring_id='rent'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: before.values,
        replacementValues: {
          'waffra_recurring_v24': jsonEncode([
            {...recurring, 'day': 3},
            {...recurring, 'id': 'rent-next', 'title': 'Next rent'},
          ]),
        },
        changedKeys: const {'waffra_recurring_v24'},
      ),
      throwsStateError,
    );

    await expectUnchanged(before);
    expect(await modules().list(WaffraFinanceModule.recurring), isEmpty);
  });
}

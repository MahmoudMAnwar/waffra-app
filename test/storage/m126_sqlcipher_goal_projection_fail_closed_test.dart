import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_finance_ui_patch.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M126: Negative acceptance for a synthetic SQLCipher goal projection./// Neither a Home edit nor an Android widget edit may silently repair
/// an inconsistent SQL row or rewrite a valid finance snapshot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const disposableKey = 'm126-disposable-sqlcipher-projection-only';
  const goal = <String, Object?>{
    'id': 'trip',
    'name': 'Trip',
    'target': 5000,
    'saved': 100,
  };

  late Directory directory;
  late WaffraEncryptedStore vault;

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: vault,
        experimentalEnabled: true,
      );

  WaffraEncryptedFinanceUiPatch editor() => WaffraEncryptedFinanceUiPatch(
        snapshot: snapshot(),
        writerDirectory: directory,
        experimentalEnabled: true,
      );

  WaffraFreshModulesRepository goals() => WaffraFreshModulesRepository(
        store: vault,
        experimentalEnabled: true,
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-m126-test-');
    vault = WaffraEncryptedStore.openAt(
      File('${directory.path}/goals.sqlite'),
      key: disposableKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault,
      experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();

    final empty = await snapshot().read();
    final seeded = await editor().saveScreenChanges(
      screenBaseline: empty.values,
      replacementValues: {'waffra_goals_v24': jsonEncode([goal])},
      changedKeys: const {'waffra_goals_v24'},
    );
    expect(seeded.generation, 1);
    expect(await goals().list(WaffraFinanceModule.goals), [goal]);
  });

  tearDown(() async {
    await vault.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('typed goal SQL tamper refuses Home edit without silently fixing row',
      () async {
    final initial = await snapshot().read();
    // Keep source_json intact while forging only a typed SQL amount. A JSON
    // equality check alone would miss this, so typed projection must be read.
    await vault.customStatement(
      "UPDATE fresh_finance_goals SET saved_minor=999 "
      "WHERE goal_id='trip'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: initial.values,
        replacementValues: {
          'waffra_goals_v24': jsonEncode([{...goal, 'saved': 200}]),
        },
        changedKeys: const {'waffra_goals_v24'},
      ),
      throwsStateError,
    );

    final after = await snapshot().read();
    expect(after.generation, initial.generation);
    expect(after.digest, initial.digest);
    expect(after.values, initial.values);
    final typedRow = await vault.customSelect(
      "SELECT saved_minor FROM fresh_finance_goals WHERE goal_id='trip'",
    ).getSingle();
    expect(typedRow.read<int>('saved_minor'), 999);
    // The suspected row must remain quarantined for verified recovery,
    // rather than being rewritten and presented as a successful screen save.
    expect(await goals().list(WaffraFinanceModule.goals), [goal]);
  });

  test('missing SQL goal refuses update and new create atomically', () async {
    final initial = await snapshot().read();
    // Synthetic corruption only: deliberately remove the typed projection
    // without touching the canonical encrypted JSON snapshot.
    await vault.customStatement(
      "DELETE FROM fresh_finance_goals WHERE goal_id='trip'",
    );

    await expectLater(
      editor().saveScreenChanges(
        screenBaseline: initial.values,
        replacementValues: {
          'waffra_goals_v24': jsonEncode([
            {...goal, 'saved': 200},
            {...goal, 'id': 'next', 'name': 'Next', 'saved': 0},
          ]),
        },
        changedKeys: const {'waffra_goals_v24'},
      ),
      throwsStateError,
    );

    final after = await snapshot().read();
    expect(after.generation, initial.generation);
    expect(after.digest, initial.digest);
    expect(after.values, initial.values);
    expect(await goals().list(WaffraFinanceModule.goals), isEmpty);
  });
}

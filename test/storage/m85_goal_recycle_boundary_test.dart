import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_goal_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

/// M85 synthetic goal-recycle acceptance. Does not touch active Home data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore db;
  const key = 'm85-disposable-goals-vault-only-key';
  final deletedAt = DateTime.utc(2026, 10, 22, 12);

  WaffraEncryptedGoalRecycle recycle() => WaffraEncryptedGoalRecycle(
    store: db, experimentalEnabled: true,
  );
  WaffraFreshModulesRepository goals() => WaffraFreshModulesRepository(
    store: db, experimentalEnabled: true,
  );
  Future<void> setupGoal() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await goals().save(WaffraFinanceModule.goals, {
      'id': 'm85-goal', 'name': 'هدف طوارئ', 'target': 10000.0,
      'saved': 1200.0,
    });
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m85-goals-');
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/goals.sqlite'), key: key,
    );
    await setupGoal();
  });
  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M85 restore just before 30-day expiry keeps target, zeros saved',
      () async {
    await recycle().deleteGoal('m85-goal', now: deletedAt);
    final beforeDeadline = deletedAt.add(
      const Duration(days: 30) - const Duration(milliseconds: 1),
    );
    expect(await recycle().listRecoverable(beforeDeadline), hasLength(1));
    await recycle().restore('m85-goal', now: beforeDeadline);
    final current = (await goals().list(WaffraFinanceModule.goals)).single;
    expect(current['target'], 10000);
    expect(current['saved'], 0);
    expect(current['id'], 'm85-goal');
  });

  test('M85 exact 30-day deadline blocks recovery and hides expired item',
      () async {
    await recycle().deleteGoal('m85-goal', now: deletedAt);
    final expiry = deletedAt.add(const Duration(days: 30));
    expect(await recycle().listRecoverable(expiry), isEmpty);
    await expectLater(
      recycle().restore('m85-goal', now: expiry),
      throwsA(isA<StateError>()),
    );
    expect(await goals().list(WaffraFinanceModule.goals), isEmpty);
  });

  test('M85 expired goal cannot be permanently purged without explicit opt-in',
      () async {
    await recycle().deleteGoal('m85-goal', now: deletedAt);
    final expired = deletedAt.add(const Duration(days: 31));
    await expectLater(
      recycle().purgeExpired(expired), throwsA(isA<StateError>()),
    );
    final entries = await db.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_goal_trash',
    ).getSingle();
    expect(entries.read<int>('n'), 1);
    expect(await recycle().purgeExpired(expired, allowPurge: true), 1);
    expect(await recycle().purgeExpired(expired, allowPurge: true), 0);
  });

  test('M85 encrypted cold restart retains recoverable goal without funds',
      () async {
    await recycle().deleteGoal('m85-goal', now: deletedAt);
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/goals.sqlite'), key: key,
    );
    expect(await recycle().listRecoverable(
      deletedAt.add(const Duration(days: 12)),
    ), hasLength(1));
    await recycle().restore(
      'm85-goal', now: deletedAt.add(const Duration(days: 12)),
    );
    expect((await goals().list(WaffraFinanceModule.goals)).single['saved'],
        0);
  });
}

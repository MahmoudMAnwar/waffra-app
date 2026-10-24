import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_goal_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore store;
  final now = DateTime.utc(2026, 10, 21, 13, 0);

  WaffraEncryptedGoalRecycle service() =>
      WaffraEncryptedGoalRecycle(store: store, experimentalEnabled: true);

  WaffraFreshModulesRepository module() =>
      WaffraFreshModulesRepository(store: store, experimentalEnabled: true);

  Future<void> prepare() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await module().save(WaffraFinanceModule.goals, {
      'id': 'goal-trip',
      'name': 'رحلة',
      'target': 10000.0,
      'saved': 1250.75,
    });
  }

  Future<void> linkTransaction() async {
    final source = jsonEncode({
      'id': 'linked-tx',
      'title': 'الادخار',
      'category': 'ادخار',
      'amount': 250,
      'income': false,
      'date': '2026-10-21T13:00:00',
      'goalId': 'goal-trip',
    });
    await store.customStatement(
      'INSERT INTO fresh_finance_entries '
      '(entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,source_json) VALUES (?,?,?,?,?,?,?)',
      ['linked-tx', 'الادخار', 'ادخار', 25000, 0,
       '2026-10-21T13:00:00', source],
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-goal-trash-');
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/goals.sqlite'),
      key: 'synthetic-recycle-test-key-32-chars',
    );
  });
  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('deleting a goal retains it in recoverable trash for 30 days',
      () async {
    await prepare();
    final result = await service().deleteGoal('goal-trip', now: now);
    expect(result.linkedTransactions, 0);
    expect(await module().list(WaffraFinanceModule.goals), isEmpty);
    final deleted = await service().listRecoverable(
      now.add(const Duration(days: 29)),
    );
    expect(deleted, hasLength(1));
    expect(deleted.single.name, 'رحلة');
    expect(deleted.single.expiresAtMs - deleted.single.deletedAtMs,
        const Duration(days: 30).inMilliseconds);
  });

  test('restoring a goal resets saved budget to zero, not its target',
      () async {
    await prepare();
    await service().deleteGoal('goal-trip', now: now);
    await service().restore('goal-trip',
        now: now.add(const Duration(days: 10)));
    final goals = await module().list(WaffraFinanceModule.goals);
    expect(goals, hasLength(1));
    expect(goals.single['id'], 'goal-trip');
    expect(goals.single['name'], 'رحلة');
    expect(goals.single['target'], 10000);
    expect(goals.single['saved'], 0);
    expect(await service().listRecoverable(now), isEmpty);
  });

  test('linked finance transactions require explicit deletion approval',
      () async {
    await prepare();
    await linkTransaction();
    await expectLater(
      service().deleteGoal('goal-trip', now: now),
      throwsA(isA<StateError>()),
    );
    expect(await module().list(WaffraFinanceModule.goals), hasLength(1));
    expect(await service().listRecoverable(now), isEmpty);
    final result = await service().deleteGoal(
      'goal-trip', now: now, acknowledgeLinkedTransactions: true,
    );
    expect(result.linkedTransactions, 1);
    expect((await service().listRecoverable(now))
        .single.linkedTransactions, 1);
    final history = await store.customSelect(
      'SELECT source_json FROM fresh_finance_entries '
      "WHERE entry_id='linked-tx'",
    ).getSingle();
    expect(history.read<String>('source_json'), contains('goal-trip'));
  });

  test('restoring a goal never rewrites related transaction history',
      () async {
    await prepare();
    await linkTransaction();
    final before = await store.customSelect(
      'SELECT source_json FROM fresh_finance_entries',
    ).getSingle();
    await service().deleteGoal(
      'goal-trip', now: now, acknowledgeLinkedTransactions: true,
    );
    await service().restore('goal-trip',
        now: now.add(const Duration(days: 5)));
    final after = await store.customSelect(
      'SELECT source_json FROM fresh_finance_entries',
    ).getSingle();
    expect(after.read<String>('source_json'),
        before.read<String>('source_json'));
    expect((await module().list(WaffraFinanceModule.goals))
        .single['saved'], 0);
  });

  test('goal cannot be restored after expiry', () async {
    await prepare();
    await service().deleteGoal('goal-trip', now: now);
    await expectLater(service().restore('goal-trip',
        now: now.add(const Duration(days: 30))),
        throwsA(isA<StateError>()));
    expect(await service().listRecoverable(
      now.add(const Duration(days: 31)),
    ), isEmpty);
  });

  test('permanent cleanup defaults to disabled even for expired trash',
      () async {
    await prepare();
    await service().deleteGoal('goal-trip', now: now);
    await expectLater(
      service().purgeExpired(now.add(const Duration(days: 45))),
      throwsA(isA<StateError>()),
    );
    expect(await service().purgeExpired(
      now.add(const Duration(days: 45)), allowPurge: true,
    ), 1);
    expect(await service().listRecoverable(now), isEmpty);
  });

  test('missing or twice-deleted goal cannot silently disappear', () async {
    await prepare();
    await expectLater(
      service().deleteGoal('nonexistent', now: now),
      throwsA(isA<StateError>()),
    );
    await service().deleteGoal('goal-trip', now: now);
    await expectLater(
      service().deleteGoal('goal-trip', now: now),
      throwsA(isA<StateError>()),
    );
    expect(await service().listRecoverable(now), hasLength(1));
  });

  test('disabled goal recycle bin changes nothing', () async {
    await prepare();
    await expectLater(WaffraEncryptedGoalRecycle(
      store: store,
    ).deleteGoal('goal-trip', now: now),
        throwsA(isA<StateError>()));
    expect(await module().list(WaffraFinanceModule.goals), hasLength(1));
  });

  test('encrypted cold reopen preserves goal trash and later recovery',
      () async {
    await prepare();
    await service().deleteGoal('goal-trip', now: now);
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/goals.sqlite'),
      key: 'synthetic-recycle-test-key-32-chars',
    );
    expect(await service().listRecoverable(now), hasLength(1));
    await service().restore('goal-trip',
        now: now.add(const Duration(days: 7)));
    expect((await module().list(WaffraFinanceModule.goals))
        .single['saved'], 0);
  });
}

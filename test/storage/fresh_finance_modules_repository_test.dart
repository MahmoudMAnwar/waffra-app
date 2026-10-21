import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

void main() {
  late Directory root;
  late WaffraEncryptedStore vault;
  const key = 'only-for-disposable-modules-test-32';

  WaffraFreshModulesRepository getRepo(bool enabled) =>
      WaffraFreshModulesRepository(
        store: vault, experimentalEnabled: enabled,
      );

  Map<String, Object?> category({String id = 'food', num budget = 250}) => {
    'id': id, 'name': 'مأكولات', 'income': false,
    'parentId': '', 'budget': budget, 'icon': 'restaurant',
    'color': 0xFF087A54, 'alertPercent': 80,
  };
  Map<String, Object?> goal({String id = 'trip', num saved = 0}) => {
    'id': id, 'name': 'رحلة', 'target': 5000, 'saved': saved,
  };
  Map<String, Object?> recurring({String id = 'bill', int day = 12}) => {
    'id': id, 'title': 'فاتورة إنترنت', 'amount': 118.5,
    'income': false, 'day': day, 'active': true,
    'category': 'فواتير', 'startAt': '2026-10-21T12:00:00',
  };

  Future<void> initialize() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-modules-');
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/modules.sqlite'), key: key,
    );
  });
  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('three UI modules can save and read exact typed attributes', () async {
    await initialize();
    final repo = getRepo(true);
    await repo.save(WaffraFinanceModule.categories, category());
    await repo.save(WaffraFinanceModule.goals, goal(saved: 120.5));
    await repo.save(WaffraFinanceModule.recurring, recurring());
    expect((await repo.list(WaffraFinanceModule.categories)).single['budget'], 250);
    expect((await repo.list(WaffraFinanceModule.goals)).single['saved'], 120.5);
    expect((await repo.list(WaffraFinanceModule.recurring)).single['day'], 12);
    expect((await repo.list(WaffraFinanceModule.recurring)).single['title'],
        'فاتورة إنترنت');
  });

  test('update preserves same identifier and prevents duplicates', () async {
    await initialize();
    final repo = getRepo(true);
    await repo.save(WaffraFinanceModule.goals, goal(saved: 0));
    await repo.save(
      WaffraFinanceModule.goals, goal(saved: 200),
      replaceExisting: true,
    );
    expect((await repo.list(WaffraFinanceModule.goals)), hasLength(1));
    expect((await repo.list(WaffraFinanceModule.goals)).single['saved'], 200);
    await expectLater(
      repo.save(WaffraFinanceModule.goals, goal(saved: 1)),
      throwsA(isA<StateError>()),
    );
    expect((await repo.list(WaffraFinanceModule.goals)).single['saved'], 200);
  });

  test('unknown ID cannot be treated as a successful update', () async {
    await initialize();
    await expectLater(
      getRepo(true).save(
        WaffraFinanceModule.categories, category(),
        replaceExisting: true,
      ), throwsA(isA<StateError>()),
    );
  });

  test('mandatory fields block invalid negative scenarios', () async {
    await initialize();
    final repo = getRepo(true);
    for (final value in [
      {...category(), 'name': ''},
      {...category(), 'income': null},
      category(budget: -1),
      {...goal(), 'target': 0},
      {...goal(), 'saved': -2},
      recurring(day: 0),
      recurring(day: 32),
      {...recurring(), 'amount': -5},
      {...recurring(), 'startAt': 'invalid'},
      {...recurring(), 'title': '  '},
    ]) {
      final type = value.containsKey('target')
          ? WaffraFinanceModule.goals
          : value.containsKey('day')
              ? WaffraFinanceModule.recurring
              : WaffraFinanceModule.categories;
      await expectLater(repo.save(type, value),
          throwsA(isA<ArgumentError>()));
    }
    expect(await repo.list(WaffraFinanceModule.categories), isEmpty);
    expect(await repo.list(WaffraFinanceModule.goals), isEmpty);
    expect(await repo.list(WaffraFinanceModule.recurring), isEmpty);
  });

  test('missing schema and disabled flag prevent finance access', () async {
    final repo = getRepo(true);
    await expectLater(repo.list(WaffraFinanceModule.categories),
        throwsA(isA<StateError>()));
    await initialize();
    await expectLater(getRepo(false).save(WaffraFinanceModule.goals, goal()),
        throwsA(isA<StateError>()));
    expect(await repo.list(WaffraFinanceModule.goals), isEmpty);
  });

  test('reopen encrypted SQLite and restore all three screen models', () async {
    await initialize();
    final repo = getRepo(true);
    await repo.save(WaffraFinanceModule.categories, category());
    await repo.save(WaffraFinanceModule.goals, goal());
    await repo.save(WaffraFinanceModule.recurring, recurring());
    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/modules.sqlite'), key: key,
    );
    for (final module in WaffraFinanceModule.values) {
      expect(await getRepo(true).list(module), hasLength(1));
    }
  });

  test('permanent delete is disabled until recycle and links are safe', () async {
    await initialize();
    await getRepo(true).save(WaffraFinanceModule.goals, goal());
    await expectLater(
      getRepo(true).delete(WaffraFinanceModule.goals, 'trip'),
      throwsA(isA<StateError>()),
    );
    expect(await getRepo(true).list(WaffraFinanceModule.goals), hasLength(1));
  });

  test('an unknown schema revision blocks changes without erasing rows',
      () async {
    await initialize();
    await getRepo(true).save(WaffraFinanceModule.recurring, recurring());
    await vault.customStatement(
      "UPDATE fresh_finance_meta SET schema_version = 500",
    );
    await expectLater(
      getRepo(true).save(WaffraFinanceModule.recurring,
          recurring(day: 14), replaceExisting: true),
      throwsA(isA<StateError>()),
    );
    final count = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_recurring',
    ).getSingle();
    expect(count.read<int>('n'), 1);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_financial_write_gate.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_recoverable_records.dart';

void main() {
  late Directory temp;
  late WaffraEncryptedStore db;
  late WaffraFinancialWriteGate gate;
  late WaffraDraftRecoverableRepository repo;
  var today = DateTime.utc(2026, 10, 21, 12);

  Map<String, Object?> source() => {
    'entries': jsonEncode([
      {
        'id': 'tx-old', 'title': 'دفعة قديمة', 'category': 'سفر',
        'amount': 125.0, 'income': false,
        'date': '2026-10-19T10:00:00', 'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': jsonEncode([
      {
        'id': 'cat-active', 'name': 'سفر', 'income': false,
        'budget': 200.0, 'color': 0xFF007F55,
      },
    ]),
    'waffra_goals_v24': jsonEncode([
      {
        'id': 'goal-active', 'name': 'رحلة', 'target': 10000.0, 'saved': 700.0,
      },
    ]),
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': jsonEncode([
      {
        'category': {
          'id': 'cat-deleted', 'name': 'قديم', 'income': false,
          'budget': 500.0,
        },
        'deletedAt': '2026-10-20T09:00:00',
      },
    ]),
    'waffra_deleted_goals_v1': jsonEncode([
      {
        'goal': {
          'id': 'goal-deleted', 'name': 'سيارة',
          'target': 20000.0, 'saved': 1000.0,
        },
        'deletedAt': '2026-10-20T09:00:00',
      },
    ]),
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[],
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  Future<void> prepare(String vaultId) async {
    await db.stageSnapshot(vaultId, source());
    await db.buildRelationalProjection(vaultId);
    await repo.prepareVerifiedVault(vaultId);
  }

  setUp(() async {
    today = DateTime.utc(2026, 10, 21, 12);
    temp = await Directory.systemTemp.createTemp('waffra-trash-');
    db = WaffraEncryptedStore.openAt(
      File(temp.path + '/vault.db'),
      key: 'test-migration-coordinator-key-32-bytes',
    );
    gate = WaffraFinancialWriteGate();
    repo = WaffraDraftRecoverableRepository(
      db: db, gate: gate, clock: () => today, experimentalEnabled: true);
  });
  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('disabled and unverified vaults do not create recoverable records',
      () async {
    final disabled = WaffraDraftRecoverableRepository(db: db, gate: gate);
    await expectLater(disabled.prepareVerifiedVault('v'),
      throwsA(isA<StateError>()));
    await expectLater(repo.prepareVerifiedVault('v'),
      throwsA(isA<StateError>()));
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE name='working_recoverables'",
    ).get();
    expect(tables, isEmpty);
  });

  test('legacy active/trash records imported and restores zero allocations',
      () async {
    await prepare('vault-one');
    final goals = await repo.records('vault-one', WaffraRecoverableKind.goal,
      includeDeleted: true);
    final cats = await repo.records('vault-one', WaffraRecoverableKind.category,
      includeDeleted: true);
    expect(goals.length, 2);
    expect(cats.length, 2);
    expect(goals.firstWhere((e) => e.id == 'goal-active').allocatedMinor,
      70000);
    expect(cats.firstWhere((e) => e.id == 'cat-active').allocatedMinor,
      20000);

    await repo.restore('vault-one', WaffraRecoverableKind.goal,
      'goal-deleted', expectedVersion: 1);
    await repo.restore('vault-one', WaffraRecoverableKind.category,
      'cat-deleted', expectedVersion: 1);
    final restoredGoal = (await repo.records(
      'vault-one', WaffraRecoverableKind.goal))
        .firstWhere((e) => e.id == 'goal-deleted');
    final restoredCat = (await repo.records(
      'vault-one', WaffraRecoverableKind.category))
        .firstWhere((e) => e.id == 'cat-deleted');
    expect(restoredGoal.allocatedMinor, 0);
    expect(restoredCat.allocatedMinor, 0);
    expect(restoredGoal.deleted, isFalse);
    expect(restoredCat.deleted, isFalse);
    expect(restoredGoal.version, 2);

    // Historical ledger and original projection remain untouched.
    expect((await db.readOriginalEntryJson('vault-one')).join(),
      contains('دفعة قديمة'));
    final shadow = await db.customSelect(
      "SELECT saved_minor FROM saving_goals WHERE vault_id=? AND goal_id=?",
      variables: [
        Variable.withString('vault-one'),
        Variable.withString('goal-deleted'),
      ],
    ).getSingle();
    expect(shadow.read<int>('saved_minor'), 100000);

    await repo.prepareVerifiedVault('vault-one');
    expect((await repo.records('vault-one', WaffraRecoverableKind.goal))
      .firstWhere((e) => e.id == 'goal-deleted').allocatedMinor, 0);
  });

  test('delete and restore enforce versions and do not touch ledger entries',
      () async {
    await prepare('vault-one');
    await repo.delete('vault-one', WaffraRecoverableKind.goal,
      'goal-active', expectedVersion: 1);
    final deleted = (await repo.records(
      'vault-one', WaffraRecoverableKind.goal, includeDeleted: true))
        .firstWhere((e) => e.id == 'goal-active');
    expect(deleted.deleted, isTrue);
    expect(deleted.version, 2);
    expect(deleted.deletedAtUtc, today);
    await expectLater(repo.delete('vault-one', WaffraRecoverableKind.goal,
      'goal-active', expectedVersion: 2), throwsA(isA<StateError>()));
    await repo.restore('vault-one', WaffraRecoverableKind.goal,
      'goal-active', expectedVersion: 2);
    final restored = (await repo.records('vault-one',
      WaffraRecoverableKind.goal)).firstWhere((e) => e.id == 'goal-active');
    expect(restored.version, 3);
    expect(restored.allocatedMinor, 0);
    expect((await db.readOriginalEntryJson('vault-one')), hasLength(1));
  });

  test('recovery after 30 days is rejected, but old data is not purged',
      () async {
    await prepare('vault-one');
    today = DateTime.utc(2026, 12, 1);
    await expectLater(
      repo.restore('vault-one', WaffraRecoverableKind.category,
        'cat-deleted', expectedVersion: 1),
      throwsA(isA<StateError>()),
    );
    final items = await repo.records('vault-one',
      WaffraRecoverableKind.category, includeDeleted: true);
    expect(items.firstWhere((e) => e.id == 'cat-deleted').deleted, isTrue);
  });

  test('isolation between vaults, stale restore is rejected', () async {
    await prepare('vault-one');
    await prepare('vault-two');
    await repo.restore('vault-one', WaffraRecoverableKind.goal,
      'goal-deleted', expectedVersion: 1);
    final second = (await repo.records('vault-two',
      WaffraRecoverableKind.goal, includeDeleted: true))
      .firstWhere((e) => e.id == 'goal-deleted');
    expect(second.deleted, isTrue);
    expect(second.allocatedMinor, 100000);
    await expectLater(
      repo.restore('vault-one', WaffraRecoverableKind.goal,
        'goal-deleted', expectedVersion: 1),
      throwsA(isA<StateError>()),
    );
  });
}

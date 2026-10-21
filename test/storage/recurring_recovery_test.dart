import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_financial_write_gate.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_recurring_recovery.dart';

void main() {
  late Directory temp;
  late WaffraEncryptedStore db;
  late WaffraFinancialWriteGate gate;
  late WaffraDraftRecurringRecovery recovery;
  var clock = DateTime.utc(2026, 10, 21, 12);

  Map<String, Object?> sample() => {
    'entries': jsonEncode([
      {
        'id': 'rec_rec-active_2026-10-20',
        'title': 'دفعة دورية موجودة', 'category': 'خدمات',
        'amount': 100.0, 'income': false,
        'date': '2026-10-20T08:00:00', 'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': jsonEncode([
      {
        'id': 'rec-active', 'title': 'إيجار',
        'category': 'سكن', 'amount': 900.0, 'income': false,
        'day': 10, 'active': true, 'startAt': '2026-01-10T00:00:00',
      },
    ]),
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': jsonEncode([
      {
        'recurring': {
          'id': 'rec-deleted', 'title': 'اشتراك',
          'category': 'خدمات', 'amount': 40.0, 'income': false,
          'day': 15, 'active': false, 'startAt': '2026-04-15T00:00:00',
        },
        'deletedAt': '2026-10-20T09:00:00',
      },
    ]),
    'waffra_recurring_postponed_v1': '{}',
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[],
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  Future<void> prepare(String vault) async {
    await db.stageSnapshot(vault, sample());
    await db.buildRelationalProjection(vault);
    await recovery.prepareVerifiedVault(vault);
  }

  setUp(() async {
    clock = DateTime.utc(2026, 10, 21, 12);
    temp = await Directory.systemTemp.createTemp('waffra-recurring-');
    db = WaffraEncryptedStore.openAt(
      File(temp.path + '/encrypted.db'),
      key: 'test-migration-coordinator-key-32-bytes',
    );
    gate = WaffraFinancialWriteGate();
    recovery = WaffraDraftRecurringRecovery(
      db: db, gate: gate, clock: () => clock, experimentalEnabled: true);
  });
  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('disabled or unverified vault cannot be prepared', () async {
    final disabled = WaffraDraftRecurringRecovery(db: db, gate: gate);
    await expectLater(disabled.prepareVerifiedVault('vault'),
        throwsA(isA<StateError>()));
    await expectLater(recovery.prepareVerifiedVault('vault'),
        throwsA(isA<StateError>()));
  });

  test('deleted recurring requires a new future date and preserves history',
      () async {
    await prepare('vault');
    expect((await recovery.items('vault')).length, 1);
    expect((await recovery.items('vault', includeDeleted: true)).length, 2);
    await expectLater(
      recovery.restore('vault', 'rec-deleted',
        expectedVersion: 1, nextDueLocalDate: '2026-10-21'),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      recovery.restore('vault', 'rec-deleted',
        expectedVersion: 1, nextDueLocalDate: '2026-02-30'),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      recovery.restore('vault', 'rec-deleted',
        expectedVersion: 1, nextDueLocalDate: ''),
      throwsA(isA<ArgumentError>()),
    );
    await recovery.restore('vault', 'rec-deleted',
      expectedVersion: 1, nextDueLocalDate: '2026-11-01');
    final restored = (await recovery.items('vault'))
      .firstWhere((r) => r.id == 'rec-deleted');
    expect(restored.deleted, isFalse);
    expect(restored.active, isTrue);
    expect(restored.version, 2);
    expect(restored.day, 1);
    expect(restored.nextDueLocalDate, '2026-11-01');

    final entries = await db.readOriginalEntryJson('vault');
    expect(entries, hasLength(1));
    expect(entries.single, contains('rec_rec-active_2026-10-20'));
    final projection = await db.customSelect(
      "SELECT due_day, deleted_at FROM recurring_bills WHERE vault_id='vault' AND recurring_id='rec-deleted'",
    ).getSingle();
    expect(projection.read<int>('due_day'), 15);
    expect(projection.readNullable<String>('deleted_at'), isNotNull);

    await recovery.prepareVerifiedVault('vault');
    expect((await recovery.items('vault'))
      .firstWhere((r) => r.id == 'rec-deleted').nextDueLocalDate, '2026-11-01');
    await expectLater(recovery.restore('vault', 'rec-deleted',
      expectedVersion: 1, nextDueLocalDate: '2026-12-01'),
      throwsA(isA<StateError>()));
  });

  test('deleting a recurring item preserves old generated transactions',
      () async {
    await prepare('vault');
    await recovery.delete('vault', 'rec-active', expectedVersion: 1);
    final trashed = (await recovery.items('vault', includeDeleted: true))
      .firstWhere((r) => r.id == 'rec-active');
    expect(trashed.deleted, isTrue);
    expect(trashed.active, isFalse);
    expect(trashed.version, 2);
    expect((await db.readOriginalEntryJson('vault')), hasLength(1));
    await expectLater(
      recovery.delete('vault', 'rec-active', expectedVersion: 2),
      throwsA(isA<StateError>()),
    );
    await recovery.restore('vault', 'rec-active', expectedVersion: 2,
      nextDueLocalDate: '2026-11-10');
    expect((await recovery.items('vault')).length, 2);
    expect((await db.readOriginalEntryJson('vault')), hasLength(1));
  });

  test('30-day expiry and separate vault data are protected', () async {
    await prepare('vault-a');
    await prepare('vault-b');
    await recovery.restore('vault-a', 'rec-deleted', expectedVersion: 1,
      nextDueLocalDate: '2026-12-05');
    expect((await recovery.items('vault-b')).length, 1);
    clock = DateTime.utc(2026, 12, 1);
    await expectLater(
      recovery.restore('vault-b', 'rec-deleted', expectedVersion: 1,
        nextDueLocalDate: '2026-12-05'),
      throwsA(isA<StateError>()),
    );
    expect((await recovery.items('vault-b', includeDeleted: true))
      .firstWhere((r) => r.id == 'rec-deleted').deleted, isTrue);
  });
}

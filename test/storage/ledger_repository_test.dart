import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_financial_write_gate.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_ledger_repository.dart';

void main() {
  late Directory sandbox;
  late File file;
  late WaffraEncryptedStore db;
  late WaffraFinancialWriteGate gate;
  late WaffraDraftSqliteLedgerRepository repo;

  Map<String, Object?> oldData({String id = 'tx-1'}) => {
    'entries': jsonEncode([
      {
        'id': id, 'title': 'راتب', 'category': 'دخل',
        'amount': 1234.50, 'income': true,
        'date': '2026-10-20T08:00:00', 'receiptPath': null,
      },
      {
        'id': 'tx-expense', 'title': 'وجبة', 'category': 'مطاعم',
        'amount': 250.0, 'income': false,
        'date': '2026-10-21T12:00:00', 'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[],
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  Future<void> prepare(String vaultId, {String id = 'tx-1'}) async {
    await db.stageSnapshot(vaultId, oldData(id: id));
    await db.buildRelationalProjection(vaultId);
    await repo.prepareVerifiedVault(vaultId);
  }

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-ledger-repo-');
    file = File(sandbox.path + '/vault.sqlite');
    db = WaffraEncryptedStore.openAt(
      file, key: 'test-migration-coordinator-key-32-bytes');
    gate = WaffraFinancialWriteGate();
    repo = WaffraDraftSqliteLedgerRepository(
      database: db, gate: gate, experimentalEnabled: true);
  });
  tearDown(() async {
    await db.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('disabled by default; cannot prepare an unverified source', () async {
    final disabled = WaffraDraftSqliteLedgerRepository(
      database: db, gate: gate);
    await expectLater(disabled.prepareVerifiedVault('vault-1'),
      throwsA(isA<StateError>()));
    await expectLater(repo.prepareVerifiedVault('vault-1'),
      throwsA(isA<StateError>()));
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE name='working_ledger_entries'",
    ).get();
    expect(rows, isEmpty);
  });

  test('verified financial parity; repeat seeding never overwrites edits',
      () async {
    await prepare('vault-1');
    final balances = await repo.balances('vault-1');
    expect(balances.incomeMinor, 123450);
    expect(balances.expenseMinor, 25000);
    expect(balances.netMinor, 98450);
    final records = await repo.entries('vault-1');
    expect(records, hasLength(2));
    expect(records.first.occurredIso, '2026-10-21T12:00:00');
    final changed = records.first.copyWith(
      title: 'وجبة معدلة', amountMinor: 15000, version: 2);
    await repo.saveEntry('vault-1', changed, expectedVersion: 1);
    expect((await repo.balances('vault-1')).expenseMinor, 15000);
    await repo.prepareVerifiedVault('vault-1');
    expect((await repo.balances('vault-1')).expenseMinor, 15000);
    final original = await db.readOriginalEntryJson('vault-1');
    expect(original.join(), contains('وجبة'));
    expect(original.join(), isNot(contains('وجبة معدلة')));
    expect(original.join(), contains('250.0'));
  });

  test('create/edit/delete/restore respect optimistic expected versions',
      () async {
    await prepare('vault-1');
    const created = WaffraLedgerItem(
      id: 'manual-income', title: 'مكافأة', category: 'دخل إضافي',
      amountMinor: 10050, isIncome: true,
      occurredIso: '2026-10-21T13:15:00', version: 1);
    await repo.saveEntry('vault-1', created, expectedVersion: 0);
    await expectLater(
      repo.saveEntry('vault-1', created, expectedVersion: 0),
      throwsA(isA<StateError>()));
    expect((await repo.balances('vault-1')).incomeMinor, 133500);
    await repo.deleteEntry('vault-1', 'manual-income', expectedVersion: 1);
    expect((await repo.entries('vault-1')).length, 2);
    expect((await repo.entries('vault-1', includeDeleted: true)).length, 3);
    expect((await repo.balances('vault-1')).incomeMinor, 123450);
    await expectLater(
      repo.saveEntry('vault-1', created.copyWith(version: 3), expectedVersion: 2),
      throwsA(isA<StateError>()));
    await expectLater(
      repo.deleteEntry('vault-1', 'manual-income', expectedVersion: 2),
      throwsA(isA<StateError>()));
    await repo.restoreEntry('vault-1', 'manual-income', expectedVersion: 2);
    final restored = (await repo.entries('vault-1'))
        .firstWhere((e) => e.id == 'manual-income');
    expect(restored.version, 3);
    expect((await repo.balances('vault-1')).incomeMinor, 133500);
    await expectLater(
      repo.restoreEntry('vault-1', 'manual-income', expectedVersion: 3),
      throwsA(isA<StateError>()));
  });

  test('vault isolation and edits persist after encrypted restart', () async {
    await prepare('vault-1');
    await prepare('vault-2', id: 'different-id');
    final edited = (await repo.entries('vault-1')).first;
    await repo.saveEntry('vault-1', edited.copyWith(
      title: 'فقط الأول', version: 2), expectedVersion: 1);
    expect((await repo.entries('vault-2')).map((e) => e.title),
      isNot(contains('فقط الأول')));
    await db.close();
    db = WaffraEncryptedStore.openAt(
      file, key: 'test-migration-coordinator-key-32-bytes');
    repo = WaffraDraftSqliteLedgerRepository(
      database: db, gate: gate, experimentalEnabled: true);
    expect((await repo.entries('vault-1')).map((e) => e.title),
      contains('فقط الأول'));
    expect((await repo.entries('vault-2')).map((e) => e.title),
      isNot(contains('فقط الأول')));
  });

  test('invalid values are refused without changing data', () async {
    await prepare('vault-1');
    final original = (await repo.entries('vault-1')).first;
    for (final invalid in [
      original.copyWith(amountMinor: -1, version: 2),
      original.copyWith(occurredIso: '2026-02-30T10:00:00', version: 2),
      original.copyWith(occurredIso: 'tomorrow', version: 2),
      original.copyWith(title: '', version: 2),
    ]) {
      await expectLater(
        repo.saveEntry('vault-1', invalid, expectedVersion: 1),
        throwsA(isA<ArgumentError>()));
    }
    expect((await repo.entries('vault-1')).first.version, 1);
    expect((await repo.balances('vault-1')).expenseMinor, 25000);
  });

  test('write-freeze holds new writes until migration lease releases',
      () async {
    await prepare('vault-1');
    final lease = await gate.freeze();
    final first = (await repo.entries('vault-1')).first;
    var persisted = false;
    final write = repo.saveEntry('vault-1',
      first.copyWith(title: 'بعد النقل', version: 2),
      expectedVersion: 1).then((_) => persisted = true);
    await Future<void>.delayed(Duration.zero);
    expect(persisted, isFalse);
    expect((await repo.entries('vault-1')).first.version, 1);
    lease.release();
    await write;
    expect(persisted, isTrue);
    expect((await repo.entries('vault-1')).first.version, 2);
  });
}

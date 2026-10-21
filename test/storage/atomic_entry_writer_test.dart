import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_entry_writer.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_financial_write_gate.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_ledger_repository.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  late Directory sandbox;
  late File file;
  late WaffraEncryptedStore db;
  late WaffraFinancialWriteGate gate;
  late WaffraDraftAtomicEntryWriter writer;
  late WaffraDraftSqliteLedgerRepository ledger;
  late SecretKey secret;

  final snapshot = <String, Object?>{
    'entries': jsonEncode([
      {
        'id': 'old-entry', 'title': 'قهوة قديمة', 'category': 'مطاعم',
        'amount': 20.0, 'income': false,
        'date': '2026-10-20T08:00:00', 'receiptPath': null,
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

  Future<void> prepare() async {
    await db.stageSnapshot('vault-test', snapshot);
    await db.buildRelationalProjection('vault-test');
    await ledger.prepareVerifiedVault('vault-test');
  }

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-atomic-');
    file = File(sandbox.path + '/vault.sqlite');
    db = WaffraEncryptedStore.openAt(
        file, key: 'testing-project-funds-not-production-32');
    gate = WaffraFinancialWriteGate();
    writer = WaffraDraftAtomicEntryWriter(
        database: db, gate: gate, experimentalEnabled: true);
    ledger = WaffraDraftSqliteLedgerRepository(
        database: db, gate: gate, experimentalEnabled: true);
    secret = await WaffraCloudCipher().newRandomVaultKey();
  });
  tearDown(() async {
    await db.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  WaffraLedgerItem newEntry({int version = 1, int amount = 12345}) =>
      WaffraLedgerItem(
        id: 'new-entry', title: 'مصروف جديد', category: 'مشتريات',
        amountMinor: amount, isIncome: false, version: version,
        occurredIso: '2026-10-21T11:00:00',
      );

  Future<WaffraAtomicEntryResult> write({
    WaffraLedgerItem? item,
    int expected = 0,
    String mutation = 'mutation-1',
    String vault = 'vault-test',
    bool deleted = false,
  }) => writer.commit(
    vaultId: vault, mutationId: mutation, deviceId: 'phone-test',
    expectedVersion: expected, item: item ?? newEntry(),
    vaultKey: secret, deleted: deleted,
  );

  test('no verified vault or disabled flag means no outbox or ledger edits',
      () async {
    await expectLater(write(), throwsA(isA<StateError>()));
    final disabled = WaffraDraftAtomicEntryWriter(
        database: db, gate: gate);
    await expectLater(disabled.commit(
      vaultId: 'vault-test', mutationId: 'm', deviceId: 'dev',
      expectedVersion: 0, item: newEntry(), vaultKey: secret,
    ), throwsA(isA<StateError>()));
    await prepare();
    expect(await ledger.entries('vault-test'), hasLength(1));
    expect(await WaffraEncryptedCloudOutbox(db)
      .pending(vaultId: 'vault-test'), isEmpty);
  });

  test('new entry, ciphertext and journal commit together', () async {
    await prepare();
    final result = await write();
    expect(result.alreadyApplied, isFalse);
    expect(result.version, 1);
    final items = await ledger.entries('vault-test');
    expect(items.length, 2);
    expect((await ledger.balances('vault-test')).expenseMinor, 14345);
    final pending = await WaffraEncryptedCloudOutbox(db)
        .pending(vaultId: 'vault-test');
    expect(pending, hasLength(1));
    expect(pending.single.envelope.mutationId, 'mutation-1');
    final clear = await WaffraCloudCipher().decrypt(
      vaultKey: secret, vaultId: 'vault-test',
      envelope: pending.single.envelope);
    expect(clear['title'], 'مصروف جديد');
    expect(clear['amount'], 123.45);
    expect(clear.containsKey('receiptPath'), isFalse);
    final original = await db.readOriginalEntryJson('vault-test');
    expect(original, hasLength(1));
    expect(original.single, contains('قهوة قديمة'));
  });

  test('exact mutation retry survives restart without new nonce or duplicate',
      () async {
    await prepare();
    await write();
    final before = (await WaffraEncryptedCloudOutbox(db)
        .pending(vaultId: 'vault-test')).single.envelope.nonce;
    await db.close();
    db = WaffraEncryptedStore.openAt(file,
      key: 'testing-project-funds-not-production-32');
    writer = WaffraDraftAtomicEntryWriter(
        database: db, gate: gate, experimentalEnabled: true);
    ledger = WaffraDraftSqliteLedgerRepository(
        database: db, gate: gate, experimentalEnabled: true);
    final again = await write();
    expect(again.alreadyApplied, isTrue);
    final after = (await WaffraEncryptedCloudOutbox(db)
        .pending(vaultId: 'vault-test')).single.envelope.nonce;
    expect(after, before);
    expect((await ledger.entries('vault-test')).length, 2);
  });

  test('changed mutation payload or stale version rolls back entirely',
      () async {
    await prepare();
    await write();
    await expectLater(write(item: newEntry(amount: 98765)),
        throwsA(isA<StateError>()));
    await expectLater(write(
      item: newEntry(version: 2, amount: 5000),
      expected: 1, mutation: 'mutation-2',
    ), completes);
    expect((await ledger.balances('vault-test')).expenseMinor, 7000);
    await expectLater(write(
      item: newEntry(version: 2, amount: 1900),
      expected: 1, mutation: 'mutation-3',
    ), throwsA(isA<StateError>()));
    final pending = await WaffraEncryptedCloudOutbox(db)
        .pending(vaultId: 'vault-test');
    // A second mutation for the same record waits for the first server ack.
    expect(pending.length, 1);
    final count = await db.customSelect('''
SELECT COUNT(*) AS n FROM working_atomic_entry_mutations
WHERE vault_id='vault-test'
''').getSingle();
    expect(count.read<int>('n'), 2);
  });

  test('invalid data and wrong vault never persist a mutation', () async {
    await prepare();
    await expectLater(write(item: newEntry(amount: -1)),
        throwsA(isA<ArgumentError>()));
    await expectLater(write(vault: 'other-vault'),
        throwsA(isA<StateError>()));
    await expectLater(write(item: newEntry().copyWith(
      occurredIso: '2026-02-30T10:00:00')),
      throwsA(isA<ArgumentError>()));
    expect((await ledger.balances('vault-test')).expenseMinor, 2000);
    expect(await WaffraEncryptedCloudOutbox(db)
      .pending(vaultId: 'vault-test'), isEmpty);
  });

  test('encrypted tombstone, no historical source deletion or re-creation',
      () async {
    await prepare();
    await write();
    await write(
      item: newEntry(version: 2), expected: 1,
      mutation: 'delete-2', deleted: true,
    );
    expect((await ledger.entries('vault-test')).length, 1);
    final all = await ledger.entries('vault-test', includeDeleted: true);
    expect(all.firstWhere((x) => x.id == 'new-entry').deleted, isTrue);
    await expectLater(write(
      item: newEntry(version: 3), expected: 2,
      mutation: 'edit-deleted',
    ), throwsA(isA<StateError>()));
    final outbox = WaffraEncryptedCloudOutbox(db);
    final initial = (await outbox.pending(vaultId: 'vault-test')).single;
    expect(initial.deleted, isFalse);
    final confirmed = WaffraRemoteRevision(
      documentId: initial.documentId, kind: initial.envelope.kind,
      mutationId: initial.envelope.mutationId,
      deviceId: initial.envelope.deviceId,
      localVersion: initial.envelope.localVersion,
      ciphertext: initial.envelope.ciphertext,
      nonce: initial.envelope.nonce, mac: initial.envelope.mac,
      deleted: false,
    );
    await outbox.acknowledge(item: initial, confirmedRemote: confirmed);
    final next = (await outbox.pending(vaultId: 'vault-test')).single;
    expect(next.deleted, isTrue);
    expect(next.envelope.localVersion, 2);
    expect((await db.readOriginalEntryJson('vault-test')), hasLength(1));
  });
}

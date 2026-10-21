import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_combined_restore_verifier.dart';
import 'package:waffra/storage/waffra_disposable_recovery_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';

void main() {
  const password = 'A long offline test archive passphrase';
  late Directory root;
  late Directory receipts;
  late WaffraEncryptedStore store;

  Map<String, Object?> snapshot() => {
    'entries': jsonEncode([
      {
        'id': 'offline-expense-1', 'title': 'Private expense',
        'category': 'Food', 'amount': 31.25, 'income': false,
        'date': '2026-10-21T12:00:00',
        'receiptPath': '/other-phone/private.jpeg',
      },
      {
        'id': 'offline-income-2', 'title': 'Salary',
        'category': 'Salary', 'amount': 5000.0, 'income': true,
        'date': '2026-10-20T12:00:00',
        'receiptPath': null,
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

  Future<String> archive() => WaffraPortableBackupV2.create(
    financialSnapshot: snapshot(),
    receipts: [
      const WaffraReceiptBackupPart(
        entryId: 'offline-expense-1', position: 0,
        bytes: [1, 2, 3, 4, 5],
      ),
    ],
    password: password,
  );

  WaffraOfflineCombinedRestoreVerifier enabled() =>
      WaffraOfflineCombinedRestoreVerifier(
        disposableStore: store, experimentalEnabled: true);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-combined-');
    receipts = await Directory('${root.path}/receipts').create();
    store = WaffraEncryptedStore.openAt(
      File('${root.path}/isolated.sqlite'),
      key: 'test-combined-restore-key-32-bytes',
    );
  });

  tearDown(() async {
    await store.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('full archive passes financial parity plus byte-exact receipt audit',
      () async {
    final report = await enabled().verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: receipts,
    );
    expect(report.transactionCount, 2);
    expect(report.receiptCount, 1);
    expect(report.receiptBytes, 5);
    expect(report.sourceChecksum, hasLength(64));
    expect(report.redactedDiagnostics['isolated_receipt_audit_passed'], isTrue);
    expect(report.redactedDiagnostics.toString(),
        isNot(contains('Private expense')));
    final rows = await store.readOriginalEntryJson('disposable-vault');
    expect(rows, hasLength(2));
    final files = await receipts.list().toList();
    expect(files, hasLength(1));
    expect(await File(files.single.path).readAsBytes(), [1, 2, 3, 4, 5]);
  });

  test('combined verification records all three durable journal phases',
      () async {
    final journalDirectory =
        await Directory('${root.path}/journal').create();
    final journal = WaffraDisposableRecoveryJournal(
      directory: journalDirectory, experimentalEnabled: true);
    final report = await enabled().verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: receipts,
      journal: journal,
    );
    final checkpoints = await journal.inspect();
    expect(report.transactionCount, 2);
    expect(checkpoints.map((x) => x.phase).toList(), [0, 1, 2]);
    expect(checkpoints.last.sourceChecksum, report.sourceChecksum);
    expect(checkpoints.last.receipts, report.receiptCount);
    expect(checkpoints.last.entries, report.transactionCount);
  });

  test('default disabled mode refuses all mutations', () async {
    await expectLater(WaffraOfflineCombinedRestoreVerifier(
      disposableStore: store).verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: receipts,
    ), throwsA(isA<StateError>()));
    expect(await receipts.list().toList(), isEmpty);
  });

  test('wrong password rejected before receipt files are staged', () async {
    await expectLater(enabled().verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: 'incorrect password',
      emptyReceiptSandboxDirectory: receipts,
    ), throwsA(anything));
    expect(await receipts.list().toList(), isEmpty);
    final row = await store.customSelect(
      'SELECT COUNT(*) AS total FROM shadow_migrations').getSingle();
    expect(row.read<int>('total'), 0);
  });

  test('refuses a populated receipt target without deleting existing data',
      () async {
    final original = File('${receipts.path}/existing.jpg');
    await original.writeAsBytes([99, 10]);
    await expectLater(enabled().verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: receipts,
    ), throwsA(isA<StateError>()));
    expect(await original.readAsBytes(), [99, 10]);
  });

  test('invalid vault ID is rejected before creating receipt files', () async {
    await expectLater(enabled().verify(
      sandboxVaultId: '../live-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: receipts,
    ), throwsA(isA<ArgumentError>()));
    expect(await receipts.list().toList(), isEmpty);
  });

  test('non-directory receipt target refused', () async {
    final fake = File('${root.path}/not-a-folder');
    await fake.writeAsBytes([42]);
    await expectLater(enabled().verify(
      sandboxVaultId: 'disposable-vault',
      encryptedArchive: await archive(),
      password: password,
      emptyReceiptSandboxDirectory: Directory(fake.path),
    ), throwsA(isA<StateError>()));
    expect(await fake.readAsBytes(), [42]);
  });
}

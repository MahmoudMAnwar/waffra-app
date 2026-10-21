import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_offline_restore_dry_run.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  const password = 'A long local archive passphrase';
  late Directory sandboxDir;
  late File sandboxFile;
  late WaffraEncryptedStore store;
  late WaffraOfflineRestoreDryRun dryRun;

  Map<String, Object?> snapshot() => {
    'entries': jsonEncode([
      {
        'id': 'entry-1', 'title': 'فاتورة خاصة',
        'category': 'طعام', 'amount': 31.25,
        'income': false, 'date': '2026-10-21T12:00:00',
        'receiptPath': '/old/device/receipt.jpg',
      },
      {
        'id': 'entry-2', 'title': 'راتب',
        'category': 'راتب', 'amount': 5000.0,
        'income': true, 'date': '2026-10-20T12:00:00',
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
    'waffra_sms_hashes_v1': <String>['hash-one'],
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  Future<String> archive() => WaffraPortableBackupV2.create(
    financialSnapshot: snapshot(),
    receipts: [
      const WaffraReceiptBackupPart(
        entryId: 'entry-1', position: 0, bytes: [1, 2, 3, 4, 5],
      ),
    ],
    password: password,
  );

  setUp(() async {
    sandboxDir = await Directory.systemTemp.createTemp(
      'waffra-restoration-sandbox-');
    sandboxFile = File(sandboxDir.path + '/sandbox.sqlite');
    store = WaffraEncryptedStore.openAt(sandboxFile,
      key: 'test-migration-coordinator-key-32-bytes');
    dryRun = WaffraOfflineRestoreDryRun(
      sandbox: store, experimentalEnabled: true);
  });
  tearDown(() async {
    await store.close();
    if (await sandboxDir.exists()) {
      await sandboxDir.delete(recursive: true);
    }
  });

  test('verified archive seeds an isolated encrypted relational working copy',
      () async {
    final original = await archive();
    final report = await dryRun.verifyIntoSandbox(
      sandboxVaultId: 'sandbox-vault',
      encryptedArchive: original, password: password);
    expect(report.verified, isTrue);
    expect(report.transactionCount, 2);
    expect(report.receiptBytesVerified, 1);
    expect(report.sourceChecksum, hasLength(64));
    expect(report.redactedDiagnostics.toString(),
        isNot(contains('فاتورة')));

    final oldJson = await store.readOriginalEntryJson('sandbox-vault');
    expect(oldJson, hasLength(2));
    expect(oldJson.join(), contains('فاتورة خاصة'));
    final projection = await store.buildRelationalProjection('sandbox-vault');
    expect(projection.incomeMinor, 500000);
    expect(projection.expenseMinor, 3125);
    expect(projection.receiptReferences, 1);

    await store.close();
    final bytes = await sandboxFile.readAsBytes();
    expect(utf8.decode(bytes, allowMalformed: true),
        isNot(contains('فاتورة خاصة')));
    expect(bytes.take(16).toList(),
        isNot(utf8.encode('SQLite format 3\u0000')));
    store = WaffraEncryptedStore.openAt(sandboxFile,
        key: 'test-migration-coordinator-key-32-bytes');
    dryRun = WaffraOfflineRestoreDryRun(
      sandbox: store, experimentalEnabled: true);
    expect(await store.readOriginalEntryJson('sandbox-vault'), oldJson);
  });

  test('identical archive may replay idempotently but different vault data cannot',
      () async {
    final first = await archive();
    final x = await dryRun.verifyIntoSandbox(
      sandboxVaultId: 'sandbox-vault',
      encryptedArchive: first, password: password);
    final again = await dryRun.verifyIntoSandbox(
      sandboxVaultId: 'sandbox-vault',
      encryptedArchive: first, password: password);
    expect(x.sourceChecksum, again.sourceChecksum);
    expect(again.transactionCount, 2);

    final otherSnapshot = snapshot();
    final entries = jsonDecode(otherSnapshot['entries']! as String) as List;
    (entries.first as Map)['amount'] = 300.00;
    otherSnapshot['entries'] = jsonEncode(entries);
    final changed = await WaffraPortableBackupV2.create(
      financialSnapshot: otherSnapshot,
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: 'entry-1', position: 0, bytes: [1, 2, 3, 4, 5]),
      ], password: password);
    await expectLater(dryRun.verifyIntoSandbox(
      sandboxVaultId: 'sandbox-vault',
      encryptedArchive: changed, password: password),
      throwsA(isA<StateError>()));
    expect((await store.readOriginalEntryJson('sandbox-vault')).join(),
      contains('"amount":31.25'));
  });

  test('tampered attachment never creates an imported vault', () async {
    final encrypted = await archive();
    final plain = await WaffraSecureBackup.decrypt(encrypted, password);
    final object = jsonDecode(plain) as Map<String, dynamic>;
    ((object['receipts'] as List).first as Map)['sha256'] = '0' * 64;
    final tampered = await WaffraSecureBackup.encrypt(
      jsonEncode(object), password);
    await expectLater(dryRun.verifyIntoSandbox(
      sandboxVaultId: 'sandbox-vault',
      encryptedArchive: tampered, password: password),
      throwsA(isA<StateError>()));

    // The failed preflight didn't stage any finance or receipt references.
    // Reading the schema itself may initialize empty shadow tables.
    // What matters is that NO archive rows were imported.
    final row = await store.customSelect(
      'SELECT COUNT(*) AS total FROM shadow_migrations',
    ).getSingle();
    expect(row.read<int>('total'), 0);
  });

  test('restore dry-run defaults to blocked and refuses wrong vault names',
      () async {
    final encrypted = await archive();
    final blocked = WaffraOfflineRestoreDryRun(sandbox: store);
    await expectLater(blocked.verifyIntoSandbox(
      sandboxVaultId: 'vault', encryptedArchive: encrypted,
      password: password), throwsA(isA<StateError>()));
    await expectLater(dryRun.verifyIntoSandbox(
      sandboxVaultId: '../outside',
      encryptedArchive: encrypted, password: password),
      throwsA(isA<ArgumentError>()));
  });
}

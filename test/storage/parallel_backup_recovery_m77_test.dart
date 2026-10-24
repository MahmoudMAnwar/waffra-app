import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

/// Runs against a disposable SQLCipher vault; no M76 receipt-save code,
/// Firebase account, native phone, real password or production source switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late WaffraEncryptedStore database;
  const sqlKey = 'm77-test-only-sqlcipher-recovery-key';
  const password = 'm77-user-chosen-recovery-test-password';

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m77-recovery-');
    database = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/restore.sqlite'), key: sqlKey,
    );
  });

  tearDown(() async {
    await database.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<String> backup(String id, {bool withReceipt = true}) =>
      WaffraPortableBackupV2.create(
        financialSnapshot: {
          'entries': jsonEncode([{
            'id': id, 'title': 'فاتورة عائلية', 'category': 'أخرى',
            'amount': 42.75, 'income': false,
            'date': '2026-10-22T12:00:00',
            'receiptPath': withReceipt ? '/old-phone/invoice.jpg' : null,
          }]),
          'waffra_goals_v24': '[]',
          'waffra_recurring_v24': '[]',
          'waffra_sms_hashes_v1': <String>['prior-message-fingerprint'],
          'waffra_custom_goals_v1': <String>['بيت'],
        },
        receipts: withReceipt
            ? [WaffraReceiptBackupPart(
                entryId: id, position: 0, bytes: const [4, 8, 15, 16],
              )]
            : [],
        password: password,
      );

  Future<bool> financeTablesExist() async {
    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_meta'",
    ).get();
    return rows.isNotEmpty;
  }

  WaffraPortableEncryptedVaultRestorer restorer() =>
      WaffraPortableEncryptedVaultRestorer(
        disposableStore: database, experimentalEnabled: true,
      );

  test('M77 a bad recovery password leaves vault empty and allows a later valid restore',
      () async {
    final archive = await backup('keep-this');
    await expectLater(restorer().restore(
      encryptedArchive: archive, password: 'wrong-recovery-key',
    ), throwsA(anything));
    expect(await financeTablesExist(), isFalse);
    final result = await restorer().restore(
      encryptedArchive: archive, password: password,
    );
    expect(result.transactionCount, 1);
    expect(result.receiptCount, 1);
    final restored = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    expect((jsonDecode(restored.values['entries'] as String) as List)
        .single['id'], 'keep-this');
    expect((await WaffraEncryptedReceiptVault(
      store: database, experimentalEnabled: true,
    ).readAll('keep-this')).single.bytes, [4, 8, 15, 16]);
  });

  test('M77 a different valid archive never overwrites an existing restored ledger',
      () async {
    await restorer().restore(
      encryptedArchive: await backup('first'), password: password,
    );
    final before = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    await expectLater(restorer().restore(
      encryptedArchive: await backup('second', withReceipt: false),
      password: password,
    ), throwsA(isA<StateError>()));
    final after = await WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    ).read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect((await WaffraEncryptedReceiptVault(
      store: database, experimentalEnabled: true,
    ).readAll('first')).single.bytes, [4, 8, 15, 16]);
  });

  test('M77 repeated cold reopening preserves receipt bytes and finance hashes',
      () async {
    await restorer().restore(
      encryptedArchive: await backup('cold-start'), password: password,
    );
    for (var restart = 0; restart < 2; restart++) {
      await database.close();
      database = WaffraEncryptedStore.openAt(
        File('${sandbox.path}/restore.sqlite'), key: sqlKey,
      );
      final state = await WaffraAtomicFinanceSnapshot(
        store: database, experimentalEnabled: true,
      ).read();
      expect((jsonDecode(state.values['entries'] as String) as List)
          .single['id'], 'cold-start');
      expect(state.values['waffra_sms_hashes_v1'],
          ['prior-message-fingerprint']);
      final attachments = await WaffraEncryptedReceiptVault(
        store: database, experimentalEnabled: true,
      ).readAll('cold-start');
      expect(attachments.single.bytes, [4, 8, 15, 16]);
    }
  });
}

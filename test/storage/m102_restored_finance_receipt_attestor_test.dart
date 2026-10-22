import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';
import 'package:waffra/storage/waffra_restored_finance_receipt_attestor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late WaffraEncryptedStore store;
  const pass = 'm102-disposable-encrypted-backup-password';
  Map<String, Object?> finances() => {
    'entries': jsonEncode([
      {
        'id': 'm102-paid', 'title': 'Synthetic paid invoice',
        'category': 'أخرى', 'amount': 84.72, 'income': false,
        'date': '2026-10-22T17:00:00',
        'receiptPath': '/old-device/private-receipt.png',
      },
      {
        'id': 'm102-income', 'title': 'Synthetic earnings',
        'category': 'دخل', 'amount': 250.0, 'income': true,
        'date': '2026-10-22T17:00:00', 'receiptPath': null,
      },
    ]),
    'waffra_goals_v24': '[]',
    'waffra_sms_hashes_v1': <String>['m102-synthetic-hash'],
  };
  Future<String> archive() => WaffraPortableBackupV2.create(
    financialSnapshot: finances(),
    receipts: [
      const WaffraReceiptBackupPart(
        entryId: 'm102-paid', position: 0, bytes: [255, 216, 1, 2],
      ),
    ],
    password: pass,
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('m102-recovery-');
    store = WaffraEncryptedStore.openAt(
      File('${temporary.path}/receipt.sqlite'),
      key: 'm102-disposable-database-only-key',
    );
  });
  tearDown(() async {
    await store.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('M102 archive -> SQLCipher -> second independent receipt-byte proof',
      () async {
    final encrypted = await archive();
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: pass,
    );
    final result = await WaffraPortableEncryptedVaultRestorer(
      disposableStore: store, experimentalEnabled: true,
    ).restore(encryptedArchive: encrypted, password: pass);
    await WaffraRestoredFinanceReceiptAttestor(
      store: store, experimentalEnabled: true,
    ).attest(authenticatedArchive: preview, reported: result);
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File('${temporary.path}/receipt.sqlite'),
      key: 'm102-disposable-database-only-key',
    );
    await WaffraRestoredFinanceReceiptAttestor(
      store: store, experimentalEnabled: true,
    ).attest(authenticatedArchive: preview, reported: result);
  });

  test('M102 forged checksum is rejected without altering source finance',
      () async {
    final encrypted = await archive();
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: pass,
    );
    final restored = await WaffraPortableEncryptedVaultRestorer(
      disposableStore: store, experimentalEnabled: true,
    ).restore(encryptedArchive: encrypted, password: pass);
    final forged = WaffraPortableEncryptedRestoreResult(
      sourceChecksum: '00000000000000000000000000000000',
      encryptedGeneration: restored.encryptedGeneration,
      transactionCount: restored.transactionCount,
      receiptCount: restored.receiptCount,
      receiptBytes: restored.receiptBytes,
    );
    await expectLater(WaffraRestoredFinanceReceiptAttestor(
      store: store, experimentalEnabled: true,
    ).attest(authenticatedArchive: preview, reported: forged),
        throwsA(isA<StateError>()));
  });

  test('M102 missing receipt SQL bytes blocks independent cutover approval',
      () async {
    final encrypted = await archive();
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: pass,
    );
    final result = await WaffraPortableEncryptedVaultRestorer(
      disposableStore: store, experimentalEnabled: true,
    ).restore(encryptedArchive: encrypted, password: pass);
    await store.customStatement(
      "DELETE FROM fresh_finance_receipt_blobs WHERE entry_id='m102-paid'",
    );
    await expectLater(WaffraRestoredFinanceReceiptAttestor(
      store: store, experimentalEnabled: true,
    ).attest(authenticatedArchive: preview, reported: result),
        throwsA(isA<StateError>()));
  });
}

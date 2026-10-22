import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M70 Android SQLCipher backup and attachment cold-restore roundtrip',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    final directory = await (await getTemporaryDirectory())
        .createTemp('waffra-m70-final-finance-');
    const secret = 'm70-android-disposable-encrypted-database-key';
    const password = 'm70-test-only-portable-backup-password';
    WaffraEncryptedStore? original;
    WaffraEncryptedStore? destination;
    try {
      final firstArchive = await WaffraPortableBackupV2.create(
        financialSnapshot: {
          'entries': jsonEncode([
            {
              'id': 'receipt-1', 'title': 'Groceries',
              'category': 'Shopping', 'amount': 31.25,
              'income': false, 'date': '2026-10-22T12:00:00',
              'receiptPath': '/old/phone/receipt.jpg',
            },
            {
              'id': 'income-1', 'title': 'Salary',
              'category': 'Income', 'amount': 1000.0,
              'income': true, 'date': '2026-10-21T12:00:00',
              'receiptPath': null,
            },
          ]),
          'waffra_goals_v24': '[]',
          'waffra_recurring_v24': '[]',
          'waffra_sms_hashes_v1': <String>['dedupe-hash-1'],
          'waffra_custom_goals_v1': <String>['سيارة'],
        },
        receipts: [
          const WaffraReceiptBackupPart(
            entryId: 'receipt-1', position: 0,
            bytes: [11, 22, 33, 44, 55],
          ),
        ],
        password: password,
      );
      original = WaffraEncryptedStore.openAt(
        File('${directory.path}/original.sqlite'), key: secret,
      );
      final restored = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: original, experimentalEnabled: true,
      ).restore(
        encryptedArchive: firstArchive, password: password,
      );
      expect(restored.transactionCount, 2);
      expect(restored.receiptCount, 1);

      final exporter = WaffraPortableEncryptedBackupExporter(
        snapshot: WaffraAtomicFinanceSnapshot(
          store: original, experimentalEnabled: true,
        ),
        receiptVault: WaffraEncryptedReceiptVault(
          store: original, experimentalEnabled: true,
        ),
        writerDirectory: directory,
        experimentalEnabled: true,
        // The whole exercise is isolated in a disposable database.
        // A real user must be verified against the active source instead.
        verifySourceUnderLock: () async {},
      );
      final encrypted = await exporter.export(password: password);
      expect(encrypted, isNot(contains('Groceries')));
      expect(encrypted, isNot(contains('/old/phone/')));
      expect(encrypted, isNot(contains('dedupe-hash-1')));
      final authenticated = await WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: encrypted, password: password,
      );
      expect(authenticated.receiptCount, 1);
      destination = WaffraEncryptedStore.openAt(
        File('${directory.path}/destination.sqlite'), key: secret,
      );
      final second = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: destination, experimentalEnabled: true,
      ).restore(
        encryptedArchive: encrypted, password: password,
      );
      expect(second.transactionCount, restored.transactionCount);
      expect(second.receiptCount, restored.receiptCount);
      expect((await WaffraEncryptedReceiptVault(
        store: destination, experimentalEnabled: true,
      ).readAll('receipt-1')).single.bytes, [11, 22, 33, 44, 55]);
      final before = await WaffraAtomicFinanceSnapshot(
        store: destination, experimentalEnabled: true,
      ).read();
      expect(before.values['waffra_sms_hashes_v1'], ['dedupe-hash-1']);
      await destination.close();
      destination = null;
      destination = WaffraEncryptedStore.openAt(
        File('${directory.path}/destination.sqlite'), key: secret,
      );
      final cold = await WaffraAtomicFinanceSnapshot(
        store: destination, experimentalEnabled: true,
      ).read();
      expect(cold.digest, before.digest);
      expect((await WaffraEncryptedReceiptVault(
        store: destination, experimentalEnabled: true,
      ).readAll('receipt-1')).single.bytes, [11, 22, 33, 44, 55]);
    } finally {
      await destination?.close();
      await original?.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}

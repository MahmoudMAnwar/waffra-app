import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_read_gateway.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android SQLCipher portable restore + private receipt cold reopen',
      (tester) async {
    expect(Platform.isAndroid, true);
    final dir = await (await getTemporaryDirectory())
        .createTemp('waffra-m66-android-verified-receipts-');
    final dbFile = File('${dir.path}/finance.sqlite');
    WaffraEncryptedStore? vault;
    const key = 'm66-android-ephemeral-only-32-key';
    try {
      final archived = await WaffraPortableBackupV2.create(
        financialSnapshot: {
          'entries': jsonEncode([
            {
              'id': 'bill-1', 'title': 'مشتريات تجربة',
              'category': 'Food', 'amount': 64.25,
              'income': false, 'date': '2026-10-22T09:00:00',
              'receiptPath': jsonEncode(['/old/photos/a.jpg', '/old/photos/b.png']),
            },
            {
              'id': 'salary-1', 'title': 'Salary',
              'category': 'Income', 'amount': 5000.0,
              'income': true, 'date': '2026-10-22T10:00:00',
              'receiptPath': null,
            },
          ]),
          'waffra_goals_v24': '[]',
          'waffra_sms_hashes_v1': <String>['already-used-sms-hash'],
        },
        receipts: [
          const WaffraReceiptBackupPart(
            entryId: 'bill-1', position: 0, bytes: [1, 2, 3, 4],
          ),
          const WaffraReceiptBackupPart(
            entryId: 'bill-1', position: 1, bytes: [5, 6, 7],
          ),
        ],
        password: 'android-receipt-verification-password',
      );
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      final restored = await WaffraPortableEncryptedVaultRestorer(
        disposableStore: vault, experimentalEnabled: true,
      ).restore(
        encryptedArchive: archived,
        password: 'android-receipt-verification-password',
      );
      expect(restored.transactionCount, 2);
      expect(restored.receiptCount, 2);
      final snapshot = await WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      ).read();
      final transactions = jsonDecode(snapshot.values['entries'] as String) as List;
      final refs = (transactions.first as Map)['receiptPath'] as String;
      expect(refs, isNot(contains('/old/photos/')));
      final reader = WaffraEncryptedReceiptReadGateway(
        receiptVault: WaffraEncryptedReceiptVault(
          store: vault, experimentalEnabled: true,
        ),
        experimentalEnabled: true,
        verifyEncryptedSource: () async {},
      );
      expect((await reader.read(
        entryId: 'bill-1', encodedReferences: refs,
      )).map((bytes) => bytes.toList()).toList(), [
        [1, 2, 3, 4], [5, 6, 7],
      ]);
      await vault.close();
      vault = null;
      final signature = await dbFile.openRead(0, 16).toList();
      final bytes = signature.expand((chunk) => chunk).toList();
      expect(bytes, isNot([83, 81, 76, 105, 116, 101, 32, 102,
                            111, 114, 109, 97, 116, 32, 51, 0]));
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      expect((await WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      ).read()).digest, snapshot.digest);
      expect((await WaffraEncryptedReceiptVault(
        store: vault, experimentalEnabled: true,
      ).readAll('bill-1')).length, 2);
    } finally {
      await vault?.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}

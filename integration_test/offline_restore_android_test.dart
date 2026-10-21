import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_combined_restore_verifier.dart';
import 'package:waffra/storage/waffra_disposable_recovery_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';

/// Android/iOS device test; uses only app-private TEMPORARY sandbox files.
/// Never touches the Waffra user's real preferences, receipt directories,
/// existing vault, biometric keys, account state or Firebase.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline finance and receipt restore survives Android disk reopen',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);

    final temporary = await getTemporaryDirectory();
    final root = await temporary.createTemp('waffra-restore-device-');
    final receiptFolder = await Directory('${root.path}/receipts').create();
    final journalFolder = await Directory('${root.path}/journal').create();
    final databaseFile = File('${root.path}/disposable-vault.sqlite');
    WaffraEncryptedStore? vault;

    try {
      vault = WaffraEncryptedStore.openAt(databaseFile,
        key: 'device-test-only-32-byte-restore-key');
      final snapshot = <String, Object?>{
        'entries': jsonEncode([
          {
            'id': 'android-expense-1', 'title': 'رسوم اختبار',
            'category': 'Test expense', 'amount': 12.75,
            'income': false, 'date': '2026-10-21T12:00:00',
            'receiptPath': '/former-device/not-in-this-phone.png',
          },
          {
            'id': 'android-income-2', 'title': 'Test income',
            'category': 'Test income', 'amount': 150.0,
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
        'waffra_sms_hashes_v1': <String>[],
        'waffra_monthly_budget_v1': 0.0,
        'waffra_monthly_budget_enabled_v1': false,
        'waffra_recurring_reminders_enabled_v1': false,
      };
      const password = 'Only for disposable device test archive';
      final archive = await WaffraPortableBackupV2.create(
        financialSnapshot: snapshot,
        receipts: [
          const WaffraReceiptBackupPart(
            entryId: 'android-expense-1', position: 0,
            bytes: [42, 43, 44, 45, 46],
          ),
        ],
        password: password,
      );
      final journal = WaffraDisposableRecoveryJournal(
        directory: journalFolder, experimentalEnabled: true);
      final report = await WaffraOfflineCombinedRestoreVerifier(
        disposableStore: vault, experimentalEnabled: true,
      ).verify(
        sandboxVaultId: 'android-disposable-only',
        encryptedArchive: archive,
        password: password,
        emptyReceiptSandboxDirectory: receiptFolder,
        journal: journal,
      );
      expect(report.transactionCount, 2);
      expect(report.receiptCount, 1);
      expect(report.receiptBytes, 5);
      expect((await journal.inspect()).map((x) => x.phase).toList(),
          [0, 1, 2]);

      final files = await receiptFolder.list().toList();
      expect(files, hasLength(1));
      expect(await File(files.single.path).readAsBytes(), [42, 43, 44, 45, 46]);

      await vault.close();
      vault = null;
      final firstBytes = await databaseFile.openRead(0, 16)
          .expand((x) => x).toList();
      expect(firstBytes, isNot(utf8.encode('SQLite format 3\u0000')),
        reason: 'Disposable finance vault must be encrypted at rest.');

      vault = WaffraEncryptedStore.openAt(databaseFile,
          key: 'device-test-only-32-byte-restore-key');
      expect(await vault.stagedRowCount('android-disposable-only'), 2);
      final reopened = WaffraDisposableRecoveryJournal(
        directory: journalFolder, experimentalEnabled: true);
      expect((await reopened.inspect()).last.sourceChecksum,
          report.sourceChecksum);
      expect(await File(files.single.path).readAsBytes(), [42, 43, 44, 45, 46]);
    } finally {
      await vault?.close();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

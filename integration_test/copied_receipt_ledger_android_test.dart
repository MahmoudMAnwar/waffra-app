import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_copied_receipt_ledger_verifier.dart';
import 'package:waffra/storage/waffra_disposable_receipt_copier.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_offline_receipt_path_planner.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';

/// Verifies the entire offline M16->M26 flow on Android/iOS *disposable data*.
/// No SharedPreferences, active database, account state or Firebase is touched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('encrypted ledger opens with verified copied receipt paths',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);

    final parent = await getTemporaryDirectory();
    final root = await parent.createTemp('waffra-copy-integration-');
    final stage = await Directory('${root.path}/stage').create();
    final copy = await Directory('${root.path}/copy').create();
    final database = File('${root.path}/isolated.sqlite');
    const key = 'device-test-receipt-ledger-key-32-chars';
    WaffraEncryptedStore? vault;

    try {
      final finance = <String, Object?>{
        'entries': jsonEncode([
          {
            'id': 'android-expense-1', 'title': 'اختبار مصروف',
            'category': 'Food', 'amount': 26.75, 'income': false,
            'date': '2026-10-21T10:00:00',
            'receiptPath': jsonEncode(['/old/mobile/one', '/old/mobile/two']),
          },
          {
            'id': 'android-income-1', 'title': 'Salary',
            'category': 'Salary', 'amount': 4800.0, 'income': true,
            'date': '2026-10-20T10:00:00', 'receiptPath': null,
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
      const secret = 'throwaway test password for Android only';
      final encrypted = await WaffraPortableBackupV2.create(
        financialSnapshot: finance,
        receipts: [
          const WaffraReceiptBackupPart(
            entryId: 'android-expense-1', position: 0,
            bytes: [10, 20, 30, 40]),
          const WaffraReceiptBackupPart(
            entryId: 'android-expense-1', position: 1,
            bytes: [50, 60, 70]),
        ], password: secret);
      final preview = await WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: encrypted, password: secret);
      final staged = await const WaffraReceiptSandboxStager(
        experimentalEnabled: true,
      ).stage(emptySandboxDirectory: stage, preview: preview);
      final plan = await const WaffraOfflineReceiptPathPlanner(
        experimentalEnabled: true,
      ).plan(
        verifiedPreview: preview, stagedReceipts: staged,
        receiptSandboxDirectory: stage, emptyAppPrivateDestination: copy,
      );
      final copied = await const WaffraDisposableReceiptCopier(
        experimentalEnabled: true,
      ).copy(
        stagingDirectory: stage, emptyDestination: copy,
        preview: preview, staged: staged, plan: plan,
      );
      expect(copied.fileCount, 2);
      expect(copied.totalBytes, 7);

      vault = WaffraEncryptedStore.openAt(database, key: key);
      final verified = await WaffraCopiedReceiptLedgerVerifier(
        disposableStore: vault, experimentalEnabled: true,
      ).verifyAndStage(
        disposableVaultId: 'android-test-vault',
        preview: preview,
        plan: plan,
        copiedReceiptDirectory: copy,
      );
      expect(verified.ledgerEntries, 2);
      expect(verified.receiptCount, 2);
      expect(verified.incomeMinor, 480000);
      expect(verified.expenseMinor, 2675);

      await vault.close();
      vault = null;
      final signature = await database.openRead(0, 16).toList();
      expect(signature.expand((x) => x).toList(),
          isNot(utf8.encode('SQLite format 3\u0000')));

      vault = WaffraEncryptedStore.openAt(database, key: key);
      final projected =
          await vault.buildRelationalProjection('android-test-vault');
      expect(projected.ledgerEntries, 2);
      expect(projected.receiptReferences, 2);
      final rows = await vault.readOriginalEntryJson('android-test-vault');
      expect(rows, hasLength(2));
      expect(rows.first, contains(copy.path));
      final diskFiles = await copy.list().toList();
      expect(diskFiles, hasLength(2));
      final bytes = <List<int>>[];
      for (final file in diskFiles) {
        bytes.add(await File(file.path).readAsBytes());
      }
      expect(bytes, contains([10, 20, 30, 40]));
      expect(bytes, contains([50, 60, 70]));
    } finally {
      await vault?.close();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';

/// Run only on disposable Android/iOS test devices:
///   flutter test integration_test/storage_encryption_android_test.dart -d <device>
/// This never opens the production app's existing SharedPreferences data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OS secure key persists and encrypted vault survives a cold reopen',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue,
        reason: 'Run on a real mobile OS, not a desktop Flutter runner.');

    final store = await WaffraEncryptedStore.openShadow();
    final source = <String, Object?>{
      'entries': jsonEncode([
        {
          'id': 'integration-entry-1',
          'title': 'اختبار معاملة',
          'category': 'تجارب',
          'amount': 13.75,
          'income': false,
          'date': '2026-10-21T11:15:00.000',
          'receiptPath': null,
        },
        {
          'id': 'integration-entry-2',
          'title': 'Test income',
          'category': 'راتب',
          'amount': 100.25,
          'income': true,
          'date': '2026-10-20T09:00:00.000',
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
    final first = await store.stageSnapshot('android-emulator-only-vault', source);
    expect(first.incomeMinor, 10025);
    expect(first.expenseMinor, 1375);
    expect(await store.stagedRowCount('android-emulator-only-vault'),
        first.recordCount);
    await store.close();

    final dir = await getApplicationSupportDirectory();
    final databaseFile = File('${dir.path}/waffra_shadow_v1.sqlite');
    expect(await databaseFile.exists(), isTrue);
    final signature = await databaseFile.openRead(0, 16).toList();
    final firstBytes = signature.expand((x) => x).toList();
    expect(firstBytes, isNot(utf8.encode('SQLite format 3\u0000')),
        reason: 'Plaintext SQLite header would mean at-rest protection failed.');

    final reopened = await WaffraEncryptedStore.openShadow();
    expect(await reopened.stagedRowCount('android-emulator-only-vault'),
        first.recordCount);
    final repeated =
        await reopened.stageSnapshot('android-emulator-only-vault', source);
    expect(repeated.sourceSha256, first.sourceSha256);
    expect(await reopened.stagedRowCount('android-emulator-only-vault'),
        first.recordCount);
    await reopened.close();
  });
}

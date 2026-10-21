import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: encrypted DB, secure key persistence, repeat import',
      (tester) async {
    // Test-only fresh emulator: never clean databases/keys belonging to users.
    final store = await WaffraEncryptedStore.openShadow();
    final financialSnapshot = <String, Object?>{
      'entries': jsonEncode([
        {
          'id': 'smoke-income',
          'title': 'الراتب',
          'category': 'راتب',
          'amount': 123.45,
          'income': true,
          'date': '2026-10-21T12:30:00.000',
          'receiptPath': null,
        },
        {
          'id': 'smoke-expense',
          'title': 'قهوة',
          'category': 'مطاعم',
          'amount': 2.50,
          'income': false,
          'date': '2026-10-21T09:30:00.000',
          'receiptPath': jsonEncode(['/missing/original.jpg', '/missing/another.jpg']),
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
    final imported = await store.stageSnapshot('android-ci-vault', financialSnapshot);
    expect(imported.incomeMinor, 12345);
    expect(imported.expenseMinor, 250);
    expect(imported.receiptReferences, 2);
    expect(await store.stagedRowCount('android-ci-vault'), imported.recordCount);
    await store.close();

    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/waffra_shadow_v1.sqlite');
    expect(await file.exists(), true);
    final bytes = await file.readAsBytes();
    expect(bytes.take(16).toList(), isNot(utf8.encode('SQLite format 3\u0000')));

    // Second open obtains the *same* device-bound key from secure storage.
    final reopened = await WaffraEncryptedStore.openShadow();
    expect(await reopened.stagedRowCount('android-ci-vault'), imported.recordCount);
    final again = await reopened.stageSnapshot('android-ci-vault', financialSnapshot);
    expect(again.sourceSha256, imported.sourceSha256);
    expect(await reopened.stagedRowCount('android-ci-vault'), imported.recordCount);
    await reopened.close();
  });
}

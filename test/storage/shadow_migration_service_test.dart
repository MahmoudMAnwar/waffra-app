import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_shadow_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-shadow-service-');
    SharedPreferences.setMockInitialValues({
      'entries': jsonEncode([
        {
          'id': 'expense1', 'title': 'مشروب', 'category': 'مطاعم',
          'amount': 10.50, 'income': false,
          'date': '2026-10-20T13:05:00.000', 'receiptPath': null,
        },
        {
          'id': 'income1', 'title': 'راتب', 'category': 'راتب',
          'amount': 100.25, 'income': true,
          'date': '2026-10-21T09:00:00.000', 'receiptPath': null,
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
      'waffra_sms_hashes_v1': <String>['hash-1'],
      'waffra_monthly_budget_v1': 500.0,
      'waffra_monthly_budget_enabled_v1': true,
      'waffra_recurring_reminders_enabled_v1': false,
      'waffra_profile': '{"name":"private"}',
      'waffra_pin_sha256': 'secret-hash',
    });
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  const service = WaffraShadowMigrationService();
  const testKey = 'test-only-encryption-key-32-byte-value';

  test('refuses migration without explicit all-writers-paused guarantee', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = WaffraEncryptedStore.openAt(
      File('${directory.path}/db.sqlite'), key: testKey);
    await expectLater(service.stageOnly(
      preferences: prefs, localVaultId: 'local-vault',
      financialWritersArePaused: false, encryptedStoreForTests: store,
    ), throwsStateError);
    expect(await store.stagedRowCount('local-vault'), 0);
    await store.close();
  });

  test('copies original preferences to encrypted tables; no legacy change', () async {
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString('entries');
    final store = WaffraEncryptedStore.openAt(
      File('${directory.path}/db.sqlite'), key: testKey);
    final report = await service.stageOnly(
      preferences: prefs, localVaultId: 'local-vault',
      financialWritersArePaused: true, encryptedStoreForTests: store,
    );
    expect(report.transactions, 2);
    expect(report.incomeMinor, 10025);
    expect(report.expenseMinor, 1050);
    expect(prefs.getString('entries'), original);
    expect(prefs.getString('waffra_profile'), '{"name":"private"}');
    expect(prefs.getString('waffra_pin_sha256'), 'secret-hash');
    final repeat = await service.stageOnly(
      preferences: prefs, localVaultId: 'local-vault',
      financialWritersArePaused: true, encryptedStoreForTests: store,
    );
    expect(repeat.sourceSha256, report.sourceSha256);
    await store.close();
  });
}

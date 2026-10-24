import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_verified_legacy_backup_restore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolated;
  late WaffraVerifiedLegacyBackupRestore restorer;

  Map<String, Object> backup({
    String? entries,
    String? goals,
  }) => <String, Object>{
    'entries': entries ??
        '[{"id":"purchase","title":"Coffee","category":"Food",'
        '"amount":9.75,"income":false,"date":"2026-10-22T08:00:00",'
        '"receiptPath":null}]',
    'waffra_categories_v24':
        '[{"id":"food","name":"Food","income":false,"budget":500}]',
    'waffra_goals_v24': goals ??
        '[{"id":"trip","name":"Trip","target":2500,"saved":200}]',
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_monthly_budget_v1': 850.75,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ],
    'waffra_recurring_reminders_enabled_v1': false,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>['old-hash'],
      'waffra_profile': '{"name":"Original profile"}',
      'waffra_language': 'ar',
    });
    isolated = await Directory.systemTemp.createTemp('waffra-backup-m63-');
    restorer = WaffraVerifiedLegacyBackupRestore(
      persistence: WaffraHomeFinancePersistence(
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: isolated,
          testBypassNativeLock: true,
        ),
      ),
    );
  });

  tearDown(() async {
    if (await isolated.exists()) await isolated.delete(recursive: true);
  });

  test('fully valid finance backup is written as a recoverable unit', () async {
    final result = await restorer.restore(
      finance: backup(),
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    );
    expect(result.transactionCount, 1);
    expect(result.sourceChecksum, hasLength(64));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), result.ledgerRaw);
    expect(prefs.getString('waffra_goals_v24'), contains('"saved":200'));
    expect(prefs.getStringList('waffra_sms_hashes_v1'), hasLength(1));
    expect(prefs.getDouble('waffra_monthly_budget_v1'), 850.75);
    expect(prefs.getString('waffra_profile'), '{"name":"Original profile"}');
    expect(prefs.getString('waffra_language'), 'ar');
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

  test('invalid goal amount prevents any backup write', () async {
    await expectLater(
      restorer.restore(
        finance: backup(goals:
          '[{"id":"trip","name":"Trip","target":2500,"saved":-1}]'),
        expectedLedgerRaw: '[]',
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['old-hash']);
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

  test('unrestorable receipt path never reports successful recovery', () async {
    await expectLater(
      restorer.restore(
        finance: backup(entries:
          '[{"id":"purchase","title":"Coffee","category":"Food",'
          '"amount":9.75,"income":false,"date":"2026-10-22T08:00:00",'
          '"receiptPath":"/old/device/receipt.png"}]'),
        expectedLedgerRaw: '[]',
        expectedWidgetRevision: null,
      ),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['old-hash']);
  });

  test('new widget transaction prevents stale backup restore', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', '[{"id":"new-widget"}]');
    await prefs.setString('waffra_widget_last_save_v1', 'widget-update');
    await expectLater(restorer.restore(
      finance: backup(),
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<StateError>()));
    expect(prefs.getString('entries'), contains('new-widget'));
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['old-hash']);
  });

  test('missing finance field is refused rather than defaulted', () async {
    final missing = backup()..remove('waffra_deleted_goals_v1');
    await expectLater(restorer.restore(
      finance: missing,
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<ArgumentError>()));
    expect((await SharedPreferences.getInstance()).getString('entries'), '[]');
  });

  test('a non-finance key cannot be smuggled into the restore', () async {
    final unsafe = backup()..['waffra_profile'] = '{"forged":true}';
    await expectLater(restorer.restore(
      finance: unsafe,
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<ArgumentError>()));
    expect((await SharedPreferences.getInstance()).getString('waffra_profile'),
        '{"name":"Original profile"}');
  });
}

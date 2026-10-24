import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolated;

  WaffraHomeFinancePersistence bridge() => WaffraHomeFinancePersistence(
    coordinator: WaffraLegacyFinanceWriterCoordinator(
      testDirectory: isolated,
      testBypassNativeLock: true,
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    isolated = await Directory.systemTemp.createTemp('waffra-home-bridge-');
  });

  tearDown(() async {
    if (await isolated.exists()) await isolated.delete(recursive: true);
  });

  test('live HomeScreen reads finance without mixing in profile settings',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"current-legacy"}]',
      'waffra_goals_v24': '[]',
      'waffra_monthly_budget_v1': 125.25,
      'waffra_sms_hashes_v1': <String>['hash-one'],
      'waffra_profile': '{"name":"test"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final screen = await bridge().loadLegacy(prefs);
    expect(screen.getString('entries'), contains('current-legacy'));
    expect(screen.getString('waffra_goals_v24'), '[]');
    expect(screen.containsKey('waffra_categories_v24'), isFalse);
    expect(screen.getDouble('waffra_monthly_budget_v1'), 125.25);
    expect(screen.getStringList('waffra_sms_hashes_v1'), ['hash-one']);
    expect(() => screen.getString('waffra_profile'),
        throwsA(isA<ArgumentError>()));
    expect(prefs.getString('waffra_profile'), '{"name":"test"}');
  });

  test('live dashboard batch retains other finance and non-finance fields',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"before"}]',
      'waffra_widget_last_save_v1': 'widget-revision-a',
      'waffra_sms_hashes_v1': <String>['existing-hash'],
      'waffra_profile': '{"name":"preserve"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final writer = bridge();
    final saved = await writer.saveLegacy(
      snapshot: {
        'entries': '[{"id":"after"}]',
        'waffra_goals_v24': '[]',
        'waffra_monthly_budget_v1': 123.50,
        'waffra_monthly_budget_enabled_v1': true,
      },
      expectedLedgerRaw: '[{"id":"before"}]',
      expectedWidgetRevision: 'widget-revision-a',
    );
    expect(saved, '[{"id":"after"}]');
    await prefs.reload();
    expect(prefs.getString('entries'), saved);
    expect(prefs.getString('waffra_goals_v24'), '[]');
    expect(prefs.getDouble('waffra_monthly_budget_v1'), 123.50);
    expect(prefs.getBool('waffra_monthly_budget_enabled_v1'), true);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), ['existing-hash']);
    expect(prefs.getString('waffra_profile'), '{"name":"preserve"}');
    expect(prefs.containsKey(WaffraLiveLegacyFinanceGuard.activeKey), false);
  });

  test('widget ledger update blocks stale dashboard write before ANY change',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"new-from-widget"}]',
      'waffra_widget_last_save_v1': 'revision-2',
      'waffra_goals_v24': '[{"id":"saved-goal"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    await expectLater(bridge().saveLegacy(
      snapshot: {
        'entries': '[{"id":"stale-dashboard"}]',
        'waffra_goals_v24': '[]',
      },
      expectedLedgerRaw: '[{"id":"old-dashboard"}]',
      expectedWidgetRevision: 'revision-1',
    ), throwsA(isA<StateError>()));
    await prefs.reload();
    expect(prefs.getString('entries'), contains('new-from-widget'));
    expect(prefs.getString('waffra_goals_v24'), contains('saved-goal'));
  });

  test('cutover evidence refuses both legacy reads and writes', () async {
    for (final marker in [
      WaffraLiveLegacyFinanceGuard.activeKey,
      WaffraLiveLegacyFinanceGuard.pendingKey,
    ]) {
      SharedPreferences.setMockInitialValues({
        'entries': '[{"id":"preserve"}]',
        marker: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await expectLater(bridge().loadLegacy(prefs),
          throwsA(isA<StateError>()));
      await expectLater(bridge().saveLegacy(
        snapshot: {'entries': '[]'},
        expectedLedgerRaw: '[{"id":"preserve"}]',
        expectedWidgetRevision: null,
      ), throwsA(isA<StateError>()));
      await prefs.reload();
      expect(prefs.getString('entries'), contains('preserve'));
    }
  });

  test('unknown preference keys and invalid batch values fail before writes',
      () async {
    SharedPreferences.setMockInitialValues({'entries': '[]'});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(bridge().saveLegacy(
      snapshot: {
        'entries': '[{"id":"new"}]',
        'waffra_profile': '{}',
      },
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<ArgumentError>()));
    await expectLater(bridge().saveLegacy(
      snapshot: {
        'entries': '[{"id":"new"}]',
        'waffra_monthly_budget_v1': 2,
      },
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<ArgumentError>()));
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
  });

  test('finance values and widget revision load from one guarded snapshot',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"widget-transaction"}]',
      'waffra_widget_last_save_v1': 'revision-after-save',
      'waffra_sms_hashes_v1': <String>['widget-hash'],
    });
    final loaded = await bridge().loadWithWitness();
    expect(loaded.ledgerRaw, contains('widget-transaction'));
    expect(loaded.widgetRevision, 'revision-after-save');
    expect(loaded.finance.getStringList('waffra_sms_hashes_v1'),
        ['widget-hash']);
  });

  test('shared live writer preserves widget SMS revision and hashes',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>['old-hash'],
    });
    final gateway = bridge();
    await gateway.withLegacyWriter((prefs) async {
      expect(prefs.getString('entries'), '[]');
      expect(await prefs.setString('entries', '[{"id":"widget-one"}]'), true);
      expect(await prefs.setStringList('waffra_sms_hashes_v1',
          <String>['old-hash', 'new-hash']), true);
      expect(await prefs.setString('waffra_widget_last_save_v1',
          'revision-one'), true);
    });
    final loaded = await gateway.loadWithWitness();
    expect(loaded.ledgerRaw, contains('widget-one'));
    expect(loaded.widgetRevision, 'revision-one');
    expect(loaded.finance.getStringList('waffra_sms_hashes_v1'),
        ['old-hash', 'new-hash']);
    await expectLater(gateway.saveLegacy(
      snapshot: {'entries': '[]'},
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<StateError>()));
    expect((await gateway.loadWithWitness()).ledgerRaw,
        contains('widget-one'));
  });

  test('transaction deletion journals ledger and SMS hashes together',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"before"}]',
      'waffra_sms_hashes_v1': <String>['old-message'],
      'waffra_profile': '{"name":"untouched"}',
    });
    final saved = await bridge().saveLegacy(
      snapshot: <String, Object>{
        'entries': '[]',
        'waffra_sms_hashes_v1': <String>[],
      },
      expectedLedgerRaw: '[{"id":"before"}]',
      expectedWidgetRevision: null,
    );
    expect(saved, '[]');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), isEmpty);
    expect(prefs.getString('waffra_profile'), '{"name":"untouched"}');
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

  test('stale deletion cannot discard a newer widget SMS or dedup hash',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"new-widget"}]',
      'waffra_sms_hashes_v1': <String>['new-widget-message'],
      'waffra_widget_last_save_v1': 'new-revision',
    });
    await expectLater(bridge().saveLegacy(
      snapshot: <String, Object>{
        'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
      },
      expectedLedgerRaw: '[]',
      expectedWidgetRevision: null,
    ), throwsA(isA<StateError>()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), contains('new-widget'));
    expect(prefs.getStringList('waffra_sms_hashes_v1'),
        ['new-widget-message']);
    expect(prefs.containsKey('waffra_legacy_finance_batch_pending_v1'), false);
  });

}

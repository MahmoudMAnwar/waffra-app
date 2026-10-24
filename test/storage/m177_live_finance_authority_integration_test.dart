import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _Source extends WaffraProductionFinanceSourceGuard {
  _Source(this.report);
  WaffraProductionFinanceSourceReport report;

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => report;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const safe = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
  const unsafe = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'pending_source_transition',
  );

  late Directory disposable;
  late _Source source;
  late WaffraVerifiedFinanceAuthority authority;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_categories_v24': '[{"id":"existing","name":"old","budget":0}]',
      'waffra_sms_hashes_v1': <String>[],
      'waffra_profile': '{"name":"untouched"}',
      'waffra_widget_last_save_v1': 'widget-r0',
    });
    disposable = await Directory.systemTemp.createTemp('waffra-m177-');
    source = _Source(safe);
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: source,
      legacy: WaffraHomeFinancePersistence(
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: disposable,
          testBypassNativeLock: true,
        ),
      ),
    );
  });

  tearDown(() async {
    if (await disposable.exists()) await disposable.delete(recursive: true);
  });

  String hash(String char) => List<String>.filled(64, char).join();

  test('M177 app SHA-only merge preserves newer widget fingerprints', () async {
    final prefs = await SharedPreferences.getInstance();
    final older = hash('a');
    final widget = hash('b');
    final added = hash('c');
    expect(await prefs.setStringList('waffra_sms_hashes_v1', [older]), isTrue);
    // Simulate a native widget append after the dashboard last loaded.
    expect(await prefs.setStringList('waffra_sms_hashes_v1', [older, widget]), isTrue);

    final actual = await authority.mergeSmsHashes([older, added, added]);
    expect(actual.finance.getStringList('waffra_sms_hashes_v1'),
        [older, widget, added]);
    await prefs.reload();
    expect(prefs.getStringList('waffra_sms_hashes_v1'), [older, widget, added]);
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getString('waffra_widget_last_save_v1'), 'widget-r0');
    expect(prefs.getString('waffra_profile'), '{"name":"untouched"}');
    await authority.mergeSmsHashes([added]);
    await prefs.reload();
    expect(prefs.getStringList('waffra_sms_hashes_v1'), [older, widget, added]);
  });

  test('M177 raw banking text cannot be written as a fingerprint', () async {
    await expectLater(authority.mergeSmsHashes(['شراء نقاط بيع - 200 ريال']),
        throwsArgumentError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('waffra_sms_hashes_v1'), <String>[]);
  });

  test('M177 reminder finance scalar uses source authority', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = await authority.setRecurringReminderPreference(true);
    expect(first.finance.getBool('waffra_recurring_reminders_enabled_v1'), true);
    final second = await authority.setRecurringReminderPreference(false);
    expect(second.finance.getBool('waffra_recurring_reminders_enabled_v1'), false);
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getString('waffra_widget_last_save_v1'), 'widget-r0');
  });

  test('M177 category install enforces compare-and-swap and durable version', () async {
    const old = '[{"id":"existing","name":"old","budget":0}]';
    const next = '[{"id":"existing","name":"old","budget":0},'
        '{"id":"extra","name":"new","budget":0}]';
    final prefs = await SharedPreferences.getInstance();
    await expectLater(authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: '[]', nextCatalogRaw: next,
      catalogChanged: true,
    ), throwsStateError);
    expect(prefs.getString('waffra_categories_v24'), old);
    expect(prefs.getBool('waffra_category_catalog_v2_installed'), isNull);
    final committed = await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: old, nextCatalogRaw: next,
      catalogChanged: true,
    );
    expect(committed.finance.getString('waffra_categories_v24'), next);
    expect(prefs.getBool('waffra_category_catalog_v2_installed'), true);
    // A repeated upgrade can only set its marker without erasing user data.
    await authority.installCategoryCatalog(
      version: 3, expectedCatalogRaw: next, nextCatalogRaw: next,
      catalogChanged: false,
    );
    expect(prefs.getBool('waffra_category_catalog_v3_installed'), true);
    expect(prefs.getString('waffra_categories_v24'), next);
    expect(prefs.getString('waffra_profile'), '{"name":"untouched"}');
  });

  test('M177 custom suggestions never bypass the finance selector', () async {
    expect(await authority.loadCustomGoalSuggestions(), isEmpty);
    expect(await authority.addCustomGoalSuggestion('New synthetic goal'), true);
    expect(await authority.addCustomGoalSuggestion('new synthetic goal'), false);
    expect(await authority.loadCustomGoalSuggestions(), ['New synthetic goal']);
  });

  test('M177 bad key or activated SQL source cannot fall back to legacy', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final blocked in [unsafe, recovery]) {
      source.report = blocked;
      await expectLater(authority.mergeSmsHashes([hash('d')]), throwsStateError);
      await expectLater(authority.setRecurringReminderPreference(true),
          throwsStateError);
      await expectLater(authority.loadCustomGoalSuggestions(), throwsStateError);
      await expectLater(authority.addCustomGoalSuggestion('unsafe'), throwsStateError);
      await expectLater(authority.installCategoryCatalog(
        version: 2,
        expectedCatalogRaw: prefs.getString('waffra_categories_v24'),
        nextCatalogRaw: '[]',
        catalogChanged: true,
      ), throwsStateError);
    }
    await prefs.reload();
    expect(prefs.getStringList('waffra_sms_hashes_v1'), <String>[]);
    expect(prefs.getBool('waffra_recurring_reminders_enabled_v1'), isNull);
    expect(prefs.getString('waffra_categories_v24'), contains('existing'));
    expect(prefs.getStringList('waffra_custom_goals_v1'), isNull);
  });

  test('M177 native legacy cutover witness blocks even after outer approval',
      () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true),
        isTrue);
    await expectLater(authority.mergeSmsHashes([hash('e')]), throwsStateError);
    await expectLater(authority.setRecurringReminderPreference(true),
        throwsStateError);
    await expectLater(authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: prefs.getString('waffra_categories_v24'),
      nextCatalogRaw: '[]', catalogChanged: true,
    ), throwsStateError);
    expect(prefs.getStringList('waffra_sms_hashes_v1'), <String>[]);
  });

  test('M177 no screen still directly uses a legacy finance write', () {
    final home = File('lib/main.dart').readAsStringSync();
    expect(home, isNot(contains('_homeFinancePersistence.withLegacyWriter(')));
    expect(home, isNot(contains('_homeFinancePersistence.loadCustomGoalSuggestions(')));
    expect(home, isNot(contains('_homeFinancePersistence.addCustomGoalSuggestion(')));
    expect(home, contains('_financeAuthority.mergeSmsHashes(hashesToSave)'));
    expect(home, contains('_financeAuthority.setRecurringReminderPreference(enabled)'));
    expect(home, contains('_financeAuthority.installCategoryCatalog('));
    expect(home, contains('await _persistSmsHashes({pendingHash!});'));
    expect(home, contains('route:WaffraFinanceRoute.fullFinanceReset'));
  });
}

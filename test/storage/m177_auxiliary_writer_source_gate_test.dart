import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _Source extends WaffraProductionFinanceSourceGuard {
  _Source(this.report);
  final WaffraProductionFinanceSourceReport report;

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => report;
}

class _Writer extends WaffraHomeFinancePersistence {
  int writerCalls = 0;
  int customReads = 0;
  int customAdds = 0;

  @override
  Future<T> withLegacyWriter<T>(
      Future<T> Function(SharedPreferences preferences) writer) async {
    writerCalls++;
    return writer(await SharedPreferences.getInstance());
  }

  @override
  Future<List<String>> loadCustomGoalSuggestions() async {
    customReads++;
    return const ['Travel'];
  }

  @override
  Future<bool> addCustomGoalSuggestion(String name) async {
    customAdds++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const legacy = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
  const encrypted = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'pending_source_transition',
  );

  setUp(() => SharedPreferences.setMockInitialValues({
    'entries': '[]',
    'waffra_sms_hashes_v1': <String>['old-hash'],
    'waffra_categories_v24': '[]',
  }));

  test('M177 hashes merge instead of replacing widget additions', () async {
    final writer = _Writer();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Source(legacy), legacy: writer,
    );
    final result = await authority.mergeSmsFingerprints(
      route: WaffraFinanceRoute.merchantRulesAndSmsHashes,
      additions: const {'new-hash', 'old-hash'},
    );
    expect(result, {'old-hash', 'new-hash'});
    expect((await SharedPreferences.getInstance())
      .getStringList('waffra_sms_hashes_v1'), ['new-hash', 'old-hash']);
    expect(writer.writerCalls, 1);
  });

  test('M177 reminder and custom goal auxiliary routes are source guarded',
      () async {
    final writer = _Writer();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Source(legacy), legacy: writer,
    );
    await authority.saveRecurringReminderSetting(
      route: WaffraFinanceRoute.recurringCreateEditDeleteRestore,
      enabled: true,
    );
    expect((await SharedPreferences.getInstance())
      .getBool('waffra_recurring_reminders_enabled_v1'), true);
    expect(await authority.loadCustomGoalSuggestions(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore), ['Travel']);
    expect(await authority.addCustomGoalSuggestion(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
      name: 'Custom'), true);
    expect(writer.customReads, 1);
    expect(writer.customAdds, 1);
  });

  test('M177 catalog refuses stale source and marks only after write',
      () async {
    final writer = _Writer();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Source(legacy), legacy: writer,
    );
    await expectLater(authority.installCategoryCatalog(
      route: WaffraFinanceRoute.categoryCatalogInstall,
      version: 2, expectedCategoriesRaw: '[{"id":"stale"}]',
      serializedCategories: '[]', categoriesChanged: true,
    ), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('waffra_category_catalog_v2_installed'), isNull);
    await authority.installCategoryCatalog(
      route: WaffraFinanceRoute.categoryCatalogInstall,
      version: 2, expectedCategoriesRaw: '[]',
      serializedCategories: '[]', categoriesChanged: true,
    );
    expect(prefs.getBool('waffra_category_catalog_v2_installed'), true);
    await expectLater(authority.installCategoryCatalog(
      route: WaffraFinanceRoute.categoryCatalogInstall,
      version: 2, expectedCategoriesRaw: '[]',
      serializedCategories: '[]', categoriesChanged: true,
    ), throwsStateError);
  });

  test('M177 encrypted or recovery source never falls back to old preferences',
      () async {
    for (final report in [encrypted, recovery]) {
      final writer = _Writer();
      final authority = WaffraVerifiedFinanceAuthority(
        sourceGuard: _Source(report), legacy: writer,
      );
      await expectLater(authority.mergeSmsFingerprints(
        route: WaffraFinanceRoute.merchantRulesAndSmsHashes,
        additions: const {'new-hash'},
      ), throwsStateError);
      await expectLater(authority.saveRecurringReminderSetting(
        route: WaffraFinanceRoute.recurringCreateEditDeleteRestore,
        enabled: true,
      ), throwsStateError);
      await expectLater(authority.loadCustomGoalSuggestions(
        route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
      ), throwsStateError);
      await expectLater(authority.addCustomGoalSuggestion(
        route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
        name: 'Other',
      ), throwsStateError);
      await expectLater(authority.installCategoryCatalog(
        route: WaffraFinanceRoute.categoryCatalogInstall,
        version: 3, expectedCategoriesRaw: '[]',
        serializedCategories: '[]', categoriesChanged: false,
      ), throwsStateError);
      expect(writer.writerCalls, 0);
      expect(writer.customReads, 0);
      expect(writer.customAdds, 0);
    }
  });

  test('M177 every Home auxiliary legacy writer is removed', () {
    final home = File('lib/main.dart').readAsStringSync();
    final authority = File(
      'lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
    expect(home, isNot(contains('_homeFinancePersistence.withLegacyWriter(')));
    expect(home, isNot(contains('_homeFinancePersistence.addCustomGoalSuggestion(')));
    expect(home, isNot(contains('_homeFinancePersistence.loadCustomGoalSuggestions(')));
    for (final route in [
      'categoryCatalogInstall', 'merchantRulesAndSmsHashes',
      'recurringCreateEditDeleteRestore', 'goalCreateEditDeleteRestore',
    ]) {
      expect(home, contains('WaffraFinanceRoute.$route'));
    }
    expect(authority, contains('Catalog source changed while startup was loading.'));
    expect(authority, contains('Encrypted catalog installation is not certified.'));
    expect(authority, contains('Encrypted reminder settings need verified SQL projection.'));
    expect(authority, contains('Encrypted custom goal suggestions are not certified.'));
    expect(home, isNot(contains('automaticallyActivateSqlCipher => true')));
  });
}

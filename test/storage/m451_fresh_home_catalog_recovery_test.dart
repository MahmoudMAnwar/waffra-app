import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show MoneyEntry, defaultCategories;
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_home_catalog_recovery.dart';
import 'package:waffra/storage/waffra_fresh_install_source.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _ActivatedSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'test_existing_authentic_fresh_source',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  String? key;
  late WaffraEncryptedStore vault;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;

  String defaults() =>
      jsonEncode(defaultCategories().map((c) => c.toJson()).toList());

  Future<WaffraVerifiedFinanceAuthority> freshAuthority() async {
    final origin = await WaffraFreshInstallSource.prepareIn(
      dir,
      readKey: () async => key,
      writeKey: (value) async { key = value; },
    );
    expect(origin, isNotNull);
    vault = WaffraEncryptedStore.openAt(
      File('${dir.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}'),
      key: key!,
    );
    snapshot = WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: vault, snapshot: snapshot, experimentalEnabled: true,
    );
    final bridge = WaffraVerifiedEncryptedFinanceBridge(
      snapshot: snapshot,
      cutoverJournal: journal,
      writerDirectory: dir,
      experimentalEnabled: true,
      allWritersRoutedVerified: true,
      secureKeyVerified: true,
    );
    return WaffraVerifiedFinanceAuthority(
      sourceGuard: _ActivatedSource(),
      freshInstall: origin,
      encryptedSession: WaffraEncryptedFinanceSession(
        bridge: bridge, experimentalEnabled: true,
      ),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('waffra-m451-home-');
    key = null;
    authority = await freshAuthority();
  });
  tearDown(() async {
    await vault.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('M451 real default catalog and empty ledger commit atomically for Home',
      () async {
    final before = await snapshot.read();
    expect(before.values.containsKey('waffra_categories_v24'), false);
    expect(before.values.containsKey('entries'), false);
    final start = await WaffraFreshHomeCatalogRecovery.load(
      authority: authority,
      defaultCategoriesJson: defaults(),
    );
    expect(start.ledgerRaw, '[]');
    expect(start.finance.getString('waffra_categories_v24'), defaults());
    expect((await snapshot.read()).generation, before.generation + 1);
    final rows = await vault.customSelect(
      'SELECT category_id FROM fresh_finance_categories',
    ).get();
    expect(rows.length, defaultCategories().length);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('entries'), false);
    expect(prefs.containsKey('waffra_categories_v24'), false);
    expect(prefs.getBool(WaffraLiveLegacyFinanceGuard.activeKey), true);
  });

  test('M451 repeated cold Home open never duplicates defaults or ledger',
      () async {
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    final afterFirst = await snapshot.read();
    final reopened = await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    expect(reopened.ledgerRaw, '[]');
    expect((await snapshot.read()).generation, afterFirst.generation);
    expect((await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_categories',
    ).getSingle()).read<int>('n'), defaultCategories().length);
  });

  test('M451 preserves existing categories and widget ledger when present',
      () async {
    final defaultRaw = defaults();
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaultRaw,
    );
    final before = await snapshot.read();
    final next = await authority.encryptedSession!.saveChangedFields(
      baseline: (await authority.load(
        route: WaffraFinanceRoute.dashboardRead,
      )).encryptedWitness!,
      changedValues: const <String, Object?>{
        'waffra_recurring_postponed_v1': '{"r1":"2026-11-04"}',
      },
    );
    expect(next.generation, before.generation + 1);
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: 'INVALID DEFAULTS NOT USED',
    );
    final latest = await snapshot.read();
    expect(latest.values['waffra_recurring_postponed_v1'],
      '{"r1":"2026-11-04"}');
    expect(latest.values['waffra_categories_v24'], defaultRaw);
    expect(latest.generation, next.generation);
  });

  test('M451 corrupted default template fails without writing finance', () async {
    final before = await snapshot.read();
    await expectLater(WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: '[]',
    ), throwsStateError);
    final after = await snapshot.read();
    expect(after.digest, before.digest);
    expect(after.generation, before.generation);
  });

  test('M451 pending activation cannot be hidden by default categories',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WaffraLiveLegacyFinanceGuard.pendingKey, 'incomplete');
    final before = await snapshot.read();
    await expectLater(WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    ), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
    expect(prefs.containsKey('waffra_categories_v24'), false);
  });

  test('M451 missing active source pointer blocks and retains vault', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(WaffraLiveLegacyFinanceGuard.activeKey);
    final before = await snapshot.read();
    // This path must never ask the user to clear storage on a failed witness.
    await expectLater(WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    ), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
  });

  test('M451 actual Home uses the same verified startup repair', () async {
    final app = File('lib/main.dart').readAsStringSync();
    final pos = app.indexOf(' Future<void> load()async {',
      app.indexOf('class _HomeScreenState'));
    final slice = app.substring(pos, app.indexOf('  _lastWidgetRevision=',pos));
    expect(slice, contains('WaffraFreshHomeCatalogRecovery.load('));
    expect(slice, contains('defaultCategories().map((category)=>category.toJson())'));
    expect(slice, isNot(contains('SharedPreferences.setString(\'entries\'')));
  });

  Map<String, Object> freshManualCapture(MoneyEntry record) => <String, Object>{
    'entries': jsonEncode([record.toJson()]),
    'waffra_categories_v24': defaults(),
    'waffra_named_budgets_v1': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_learned_merchants_v1': '{}',
  };

  MoneyEntry freshEntry(String id, {bool sms = false}) => MoneyEntry(
    id: id,
    title: sms ? 'Verified incoming transfer' : 'Salary',
    category: defaultCategories().firstWhere(
      (c) => c.income && c.isSubcategory,
    ).name,
    amount: sms ? 50.0 : 100.0,
    income: true,
    date: DateTime.utc(2026, 11, 5, 10),
    sourceType: sms ? 'sms' : 'manual',
    notes: sms ? 'Incoming transfer SAR 50' : '',
  );

  test('M455 fresh SQLCipher Home can save its first manual income', () async {
    final start = await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    expect(start.finance.containsKey('waffra_goals_v24'), false);
    final committed = await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: start,
      captured: freshManualCapture(freshEntry('m455-manual-1')),
      userConfirmed: true,
    );
    final rows = jsonDecode(committed.ledgerRaw!) as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map)['id'], 'm455-manual-1');
    // Empty UI defaults are compared, not written as an unrelated mutation.
    expect(committed.finance.containsKey('waffra_goals_v24'), false);
    expect(committed.encryptedWitness, isNotNull);
    expect((await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle()).read<int>('n'), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('entries'), false);
  });


  test('M455 fresh SQLCipher Home can save its first manual expense', () async {
    final start = await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    final expense = MoneyEntry(
      id: 'm455-expense-1',
      title: 'Groceries',
      category: defaultCategories().firstWhere(
        (c) => !c.income && c.isSubcategory,
      ).name,
      amount: 20.5,
      income: false,
      date: DateTime.utc(2026, 11, 5, 12),
      sourceType: 'manual',
    );
    final committed = await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: start,
      captured: freshManualCapture(expense),
      userConfirmed: true,
    );
    final rows = jsonDecode(committed.ledgerRaw!) as List;
    expect(rows, hasLength(1));
    expect((rows.single as Map)['income'], false);
    expect(rows.single['amount'], 20.5);
    expect((await vault.customSelect(
      'SELECT amount_minor FROM fresh_finance_entries',
    ).getSingle()).read<int>('amount_minor'), 2050);
  });

  test('M455 first manual save rejects nonempty unrelated missing field',
      () async {
    final start = await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    final before = await snapshot.read();
    final illegal = freshManualCapture(freshEntry('m455-reject-1'))
      ..['waffra_goals_v24'] = '[{"id":"unsaved-goal"}]';
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: start, captured: illegal, userConfirmed: true,
    ), throwsStateError);
    final after = await snapshot.read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(after.values['entries'], '[]');
  });

  test('M455 first bank SMS uses the same fresh source and saves once',
      () async {
    await WaffraFreshHomeCatalogRecovery.load(
      authority: authority, defaultCategoriesJson: defaults(),
    );
    final sms = freshEntry('m455-sms-1', sms: true);
    final hash = List<String>.filled(64, 'a').join();
    final committed = await authority.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms.toJson()],
      hashes: [hash],
      userConfirmed: true,
    );
    expect(committed.saved, 1);
    expect(committed.income, 1);
    expect((jsonDecode(committed.current.ledgerRaw!) as List).length, 1);
    expect(committed.current.finance.getStringList('waffra_sms_hashes_v1'),
      contains(hash));
    final retried = await authority.commitConfirmedSms(
      route: WaffraFinanceRoute.bulkSmsConfirmedSave,
      records: [sms.toJson()],
      hashes: [hash], userConfirmed: true,
    );
    expect(retried.saved, 0);
    expect(retried.skippedDuplicates, 1);
    expect((jsonDecode(retried.current.ledgerRaw!) as List).length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('entries'), false);
  });
}

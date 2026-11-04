import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show defaultCategories;
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
}

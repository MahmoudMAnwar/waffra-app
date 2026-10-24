import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _SyntheticSqlOnlySource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_lab_not_release',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late WaffraEncryptedStore vault;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedFinanceSession session;
  late WaffraVerifiedFinanceAuthority authority;
  const first = '{"id":"food","name":"Food","income":false,"budget":0}';
  const second = '{"id":"transport","name":"Transport","income":false,"budget":0}';
  const v2 = '[$first]';
  const v3 = '[$first,$second]';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    temporary = await Directory.systemTemp.createTemp('waffra-m181-catalog-');
    vault = WaffraEncryptedStore.openAt(
      File('${temporary.path}/disposable.sqlite'),
      key: 'm181-synthetic-disposable-vault-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final baseline = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: vault, snapshot: snapshot, experimentalEnabled: true,
    );
    final preflight = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: preflight.sourceSha256,
      targetDigest: baseline.digest,
      now: DateTime.utc(2026, 10, 24),
    );
    await journal.verify(now: DateTime.utc(2026, 10, 24));
    await journal.acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 10, 24),
    );
    session = WaffraEncryptedFinanceSession(
      experimentalEnabled: true,
      bridge: WaffraVerifiedEncryptedFinanceBridge(
        snapshot: snapshot,
        cutoverJournal: journal,
        writerDirectory: temporary,
        experimentalEnabled: true,
        allWritersRoutedVerified: true,
        secureKeyVerified: true,
      ),
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _SyntheticSqlOnlySource(),
      encryptedSession: session,
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
      audit: WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values.toSet(),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      ),
    );
  });

  tearDown(() async {
    await vault.close();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('M181 v2+v3 install is typed, atomic and has durable markers', () async {
    final before = await snapshot.read();
    final loadedV2 = await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    );
    expect(loadedV2.finance.getString('waffra_categories_v24'), v2);
    expect((await snapshot.read()).generation, before.generation + 1);
    final firstProjection = await vault.customSelect(
      'SELECT category_id,name FROM fresh_finance_categories '
      'ORDER BY category_id',
    ).get();
    expect(firstProjection.length, 1);
    expect(firstProjection.single.read<String>('category_id'), 'food');
    final markersV2 = await vault.customSelect(
      "SELECT setting_key,value_json FROM fresh_finance_settings "
      "WHERE setting_key='waffra_category_catalog_v2_installed'",
    ).get();
    expect(markersV2.single.read<String>('value_json'), 'true');

    final loadedV3 = await authority.installCategoryCatalog(
      version: 3, expectedCatalogRaw: v2, nextCatalogRaw: v3,
      catalogChanged: true,
    );
    expect(loadedV3.finance.getString('waffra_categories_v24'), v3);
    final projection = await vault.customSelect(
      'SELECT category_id FROM fresh_finance_categories ORDER BY category_id',
    ).get();
    expect(projection.map((x) => x.read<String>('category_id')).toList(),
        ['food', 'transport']);
    final markers = await vault.customSelect(
      'SELECT setting_key FROM fresh_finance_settings '
      "WHERE setting_key LIKE 'waffra_category_catalog_v%_installed' "
      'ORDER BY setting_key',
    ).get();
    expect(markers.length, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('waffra_categories_v24'), isFalse);
    expect(prefs.containsKey('waffra_category_catalog_v2_installed'), isFalse);
  });

  test('M181 same version retry cannot add duplicate categories', () async {
    await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    );
    final prev = await snapshot.read();
    await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: v2, nextCatalogRaw: v2,
      catalogChanged: false,
    );
    final next = await snapshot.read();
    expect(next.generation, prev.generation);
    final rows = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_categories',
    ).getSingle();
    expect(rows.read<int>('n'), 1);
  });

  test('M181 stale category catalog is refused without data loss', () async {
    await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    );
    final before = await snapshot.read();
    await expectLater(authority.installCategoryCatalog(
      version: 3, expectedCatalogRaw: null, nextCatalogRaw: v3,
      catalogChanged: true,
    ), throwsStateError);
    final after = await snapshot.read();
    expect(after.digest, before.digest);
    final markers = await vault.customSelect(
      "SELECT setting_key FROM fresh_finance_settings "
      "WHERE setting_key='waffra_category_catalog_v3_installed'",
    ).get();
    expect(markers, isEmpty);
  });

  test('M181 invalid category projection rolls back marker and finance', () async {
    final before = await snapshot.read();
    const invalid =
        '[{"id":"invalid","name":"Missing type","budget":0}]';
    await expectLater(authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: invalid,
      catalogChanged: true,
    ), throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())));
    final after = await snapshot.read();
    expect(after.digest, before.digest);
    final rows = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_categories',
    ).getSingle();
    expect(rows.read<int>('n'), 0);
    final markers = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_settings',
    ).getSingle();
    expect(markers.read<int>('n'), 0);
  });

  test('M181 concurrent unrelated Widget fingerprint remains intact', () async {
    const fingerprint =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final baseline = await session.loadForDashboardOrWidget();
    await session.addSmsHashes([fingerprint]);
    await authority.installCategoryCatalog(
      version: 2,
      expectedCatalogRaw:
          baseline.snapshot.values['waffra_categories_v24'] as String?,
      nextCatalogRaw: v2,
      catalogChanged: true,
    );
    final snapshotAfter = await snapshot.read();
    expect(snapshotAfter.values['waffra_sms_hashes_v1'], [fingerprint]);
    expect(jsonDecode(snapshotAfter.values['waffra_categories_v24'] as String),
        hasLength(1));
  });

  test('M181 pending source and unsupported version fail closed', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    final before = await snapshot.read();
    await expectLater(authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    ), throwsStateError);
    await expectLater(authority.installCategoryCatalog(
      version: 4, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    ), throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())));
    expect((await snapshot.read()).digest, before.digest);
    expect(prefs.containsKey('waffra_categories_v24'), isFalse);
  });


  Map<String, Object?> manualEntry(String id) => <String, Object?>{
    'id': id, 'title': 'Synthetic cash entry', 'category': 'Other',
    'amount': 12.5, 'income': false, 'date': '2026-10-24T08:00:00.000Z',
    'receiptPath': null,
  };

  test('M181 manual Home add uses atomic typed SQL without losing Widget hashes',
      () async {
    const fingerprint =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final original = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    await session.addSmsHashes([fingerprint]);
    final entry = manualEntry('manual-synthetic-1');
    final committed = await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: original,
      captured: <String, Object>{
        'entries': jsonEncode([entry]),
      },
    );
    expect(jsonDecode(committed.ledgerRaw!), hasLength(1));
    final sql = await vault.customSelect(
      "SELECT entry_id,amount_minor FROM fresh_finance_entries "
      "WHERE entry_id='manual-synthetic-1'",
    ).get();
    expect(sql.length, 1);
    expect(sql.single.read<int>('amount_minor'), 1250);
    final latest = await snapshot.read();
    expect(latest.values['waffra_sms_hashes_v1'], [fingerprint]);
  });

  test('M181 manual Home add rejects mixed edits and preserves old SQL', () async {
    final baseline = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final first = manualEntry('manual-synthetic-2');
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: baseline,
      captured: <String, Object>{
        'entries': jsonEncode([first]),
        'waffra_goals_v24': '[]',
      },
    ), throwsStateError);
    final after = await snapshot.read();
    expect(after.values['entries'], '[]');
    final sql = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(sql.read<int>('n'), 0);
  });

  test('M181 manual Home duplicate ID fails without partial commit', () async {
    final before = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final entry = manualEntry('manual-synthetic-3');
    await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: before,
      captured: <String, Object>{
        'entries': jsonEncode([entry]),
      },
    );
    final next = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final mutated = Map<String, Object?>.from(entry)..['amount'] = 23.0;
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: next,
      captured: <String, Object>{
        'entries': jsonEncode([mutated]),
      },
    ), throwsStateError);
    final rows = jsonDecode((await snapshot.read()).values['entries'] as String)
        as List<dynamic>;
    expect(rows.length, 1);
    expect((rows.single as Map)['amount'], 12.5);
  });

  test('M181 source is disabled by default in production-like session', () async {
    final disabled = WaffraEncryptedFinanceSession(
      bridge: session.bridge, experimentalEnabled: false,
    );
    await expectLater(disabled.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    ), throwsStateError);
  });
}

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
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

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

  test('M235 catalog v4 commits new leaves atomically and skips repeat marker',
      () async {
    await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    );
    await authority.installCategoryCatalog(
      version: 3, expectedCatalogRaw: v2, nextCatalogRaw: v3,
      catalogChanged: true,
    );
    final v4 = jsonEncode([
      jsonDecode(first), jsonDecode(second),
      {'id': 'education', 'name': 'Education',
       'income': false, 'budget': 0},
    ]);
    final verified = await authority.installCategoryCatalog(
      version: 4, expectedCatalogRaw: v3, nextCatalogRaw: v4,
      catalogChanged: true,
    );
    expect(verified.source, WaffraRuntimeFinanceBackend.verifiedEncrypted);
    expect(jsonDecode(verified.finance.getString('waffra_categories_v24')!),
        hasLength(3));
    final encryptedMarker = await vault.customSelect(
      "SELECT value_json FROM fresh_finance_settings "
      "WHERE setting_key='waffra_category_catalog_v4_installed'",
    ).getSingle();
    expect(encryptedMarker.read<String>('value_json'), 'true');
    final before = await snapshot.read();
    await authority.installCategoryCatalog(
      version: 4, expectedCatalogRaw: v4, nextCatalogRaw: v4,
      catalogChanged: false,
    );
    final after = await snapshot.read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('waffra_category_catalog_v4_installed'), isFalse);
    expect(prefs.containsKey('waffra_categories_v24'), isFalse);
  });

  test('M235 SQLCipher catalog v4 refuses stale witness without creating marker',
      () async {
    await authority.installCategoryCatalog(
      version: 2, expectedCatalogRaw: null, nextCatalogRaw: v2,
      catalogChanged: true,
    );
    await expectLater(authority.installCategoryCatalog(
      version: 4, expectedCatalogRaw: null, nextCatalogRaw: v3,
      catalogChanged: true,
    ), throwsStateError);
    final rows = await vault.customSelect(
      "SELECT setting_key FROM fresh_finance_settings "
      "WHERE setting_key='waffra_category_catalog_v4_installed'",
    ).get();
    expect(rows, isEmpty);
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

  test('M248 encrypted manual append refuses implicit or cancelled approval', () async {
    final original = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final digest = (await snapshot.read()).digest;
    final entry = manualEntry('m248-unconfirmed-no-write');
    final captured = <String, Object>{
      'entries': jsonEncode([entry]),
    };
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: original,
      captured: captured,
    ), throwsStateError);
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: original,
      captured: captured,
      userConfirmed: false,
    ), throwsStateError);
    final unchanged = await snapshot.read();
    expect(unchanged.digest, digest);
    expect(unchanged.values['entries'], '[]');
    final actual = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(actual.read<int>('n'), 0);
  });

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
      userConfirmed: true,
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
      userConfirmed: true,
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
      userConfirmed: true,
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
      userConfirmed: true,
    ), throwsStateError);
    final rows = jsonDecode((await snapshot.read()).values['entries'] as String)
        as List<dynamic>;
    expect(rows.length, 1);
    expect((rows.single as Map)['amount'], 12.5);
  });


  test('M181 challenge and monthly budget store atomically in SQLCipher',
      () async {
    final baseline = await authority.load(
      route: WaffraFinanceRoute.challengeAndBudgetUpdate,
    );
    const challenges =
        '[{"id":"daily-1","dailyAmount":4.5,"name":"Synthetic"}]';
    final next = await authority.saveCaptured(
      route: WaffraFinanceRoute.challengeAndBudgetUpdate,
      baseline: baseline,
      captured: const <String, Object>{
        'waffra_challenges_v1': challenges,
        'waffra_monthly_budget_v1': 800.25,
        'waffra_monthly_budget_enabled_v1': true,
      },
    );
    expect(next.finance.getString('waffra_challenges_v1'), challenges);
    final stored = await snapshot.read();
    expect(stored.values['waffra_monthly_budget_v1'], 800.25);
    expect(stored.values['waffra_monthly_budget_enabled_v1'], true);
  });

  test('M181 stale budget change fails without partial financial write',
      () async {
    final route = WaffraFinanceRoute.challengeAndBudgetUpdate;
    final first = await authority.load(route: route);
    final second = await authority.load(route: route);
    await authority.saveCaptured(
      route: route, baseline: first,
      captured: const <String, Object>{
        'waffra_monthly_budget_v1': 1000.0,
      },
    );
    final previous = await snapshot.read();
    await expectLater(authority.saveCaptured(
      route: route, baseline: second,
      captured: const <String, Object>{
        'waffra_monthly_budget_v1': 500.0,
      },
    ), throwsStateError);
    final after = await snapshot.read();
    expect(after.digest, previous.digest);
    expect(after.values['waffra_monthly_budget_v1'], 1000.0);
  });

  test('M181 recurring postpone-only and merchant rules are source routed',
      () async {
    final postpone = WaffraFinanceRoute.recurringPostingAndPostponement;
    final loaded = await authority.load(route: postpone);
    final saved = await authority.saveCaptured(
      route: postpone, baseline: loaded,
      captured: const <String, Object>{
        'waffra_recurring_postponed_v1': '{"recurring-1":"2026-11-03"}',
      },
    );
    expect(saved.finance.getString('waffra_recurring_postponed_v1'),
        '{"recurring-1":"2026-11-03"}');
    final merchant = WaffraFinanceRoute.merchantRulesAndSmsHashes;
    final beforeRules = await authority.load(route: merchant);
    final afterRules = await authority.saveCaptured(
      route: merchant, baseline: beforeRules,
      captured: const <String, Object>{
        'waffra_learned_merchants_v1': '{"test-merchant":"Food"}',
      },
    );
    expect(afterRules.finance.getString('waffra_learned_merchants_v1'),
        '{"test-merchant":"Food"}');
  });

  test('M181 recurring payment cannot write ledger via scalar shortcut',
      () async {
    final route = WaffraFinanceRoute.recurringPostingAndPostponement;
    final baseline = await authority.load(route: route);
    final previous = await snapshot.read();
    await expectLater(authority.saveCaptured(
      route: route, baseline: baseline,
      captured: <String, Object>{
        'entries': jsonEncode([manualEntry('unsafe-posting')]),
        'waffra_recurring_postponed_v1': '{}',
      },
    ), throwsStateError);
    final now = await snapshot.read();
    expect(now.digest, previous.digest);
    expect(now.values['entries'], '[]');
  });


  test('M181 consented empty-receipt delete-all atomically resets IDs and hashes',
      () async {
    final original = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final entry = manualEntry('m181-delete-no-receipt');
    await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: original,
      captured: <String, Object>{'entries': jsonEncode([entry])},
      userConfirmed: true,
    );
    const fingerprint =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    await session.addSmsHashes([fingerprint]);
    final before = await authority.load(
      route: WaffraFinanceRoute.deleteAllTransactions,
    );
    final deleted = await authority.saveCaptured(
      route: WaffraFinanceRoute.deleteAllTransactions,
      baseline: before,
      captured: <String, Object>{
        'entries': '[]',
        'waffra_sms_hashes_v1': <String>[],
      },
      userConfirmed: true,
    );
    expect(deleted.ledgerRaw, '[]');
    expect(deleted.finance.getStringList('waffra_sms_hashes_v1'), isEmpty);
    final entries = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    final hashes = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_sms_hashes',
    ).getSingle();
    expect(entries.read<int>('n'), 0);
    expect(hashes.read<int>('n'), 0);
  });

  test('M181 delete-all requires explicit consent and exact capture', () async {
    final baseline = await authority.load(
      route: WaffraFinanceRoute.deleteAllTransactions,
    );
    final previous = await snapshot.read();
    for (final payload in <Map<String, Object>>[
      <String, Object>{'entries': '[]'},
      <String, Object>{
        'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
        'waffra_goals_v24': '[]',
      },
    ]) {
      await expectLater(authority.saveCaptured(
        route: WaffraFinanceRoute.deleteAllTransactions,
        baseline: baseline, captured: payload, userConfirmed: true,
      ), throwsStateError);
    }
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.deleteAllTransactions,
      baseline: baseline,
      captured: <String, Object>{
        'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
      },
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, previous.digest);
  });

  test('M181 delete-all blocks an independent concurrent Widget write', () async {
    final old = await authority.load(
      route: WaffraFinanceRoute.deleteAllTransactions,
    );
    const fingerprint =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    await session.addSmsHashes([fingerprint]);
    final now = await snapshot.read();
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.deleteAllTransactions,
      baseline: old,
      captured: <String, Object>{
        'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
      },
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, now.digest);
  });

  test('M181 delete-all blocks orphan receipt SQL rows and rolls back', () async {
    final old = await authority.load(
      route: WaffraFinanceRoute.manualTransactionSave,
    );
    final entry = manualEntry('m181-receipt-owned-record');
    await authority.saveCaptured(
      route: WaffraFinanceRoute.manualTransactionSave,
      baseline: old,
      captured: <String, Object>{'entries': jsonEncode([entry])},
      userConfirmed: true,
    );
    await vault.customStatement(
      'INSERT INTO fresh_finance_receipts '
      '(entry_id,position,safe_filename,sha256_hex) VALUES(?,?,?,?)',
      ['m181-receipt-owned-record', 0, 'synthetic.bin',
       List<String>.filled(64, 'f').join()],
    );
    final before = await authority.load(
      route: WaffraFinanceRoute.deleteAllTransactions,
    );
    final checksum = (await snapshot.read()).digest;
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.deleteAllTransactions,
      baseline: before,
      captured: <String, Object>{
        'entries': '[]', 'waffra_sms_hashes_v1': <String>[],
      },
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, checksum);
    final count = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(count.read<int>('n'), 1);
  });


  test('M181 SHA hash merge commits typed SQL and canonical snapshot together',
      () async {
    const fingerprint =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    final before = await snapshot.read();
    await session.addSmsHashes([fingerprint]);
    final typed = await vault.customSelect(
      'SELECT message_hash FROM fresh_finance_sms_hashes',
    ).get();
    expect(typed.length, 1);
    expect(typed.single.read<String>('message_hash'), fingerprint);
    final committed = await snapshot.read();
    expect(committed.generation, before.generation + 1);
    expect(committed.values['waffra_sms_hashes_v1'], [fingerprint]);
    await session.addSmsHashes([fingerprint]);
    expect((await snapshot.read()).generation, committed.generation);
  });

  test('M181 tampered typed SHA hash rejects snapshot overwrite', () async {
    const fingerprint =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    final prior = await snapshot.read();
    await vault.customStatement(
      'INSERT INTO fresh_finance_sms_hashes(message_hash) VALUES (?)',
      [fingerprint],
    );
    await expectLater(session.addSmsHashes([fingerprint]), throwsStateError);
    final after = await snapshot.read();
    expect(after.digest, prior.digest);
    expect(after.values.containsKey('waffra_sms_hashes_v1'), isFalse);
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

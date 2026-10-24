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
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';
import 'package:waffra/storage/waffra_verified_module_ui_guard.dart';

class _SyntheticActivatedSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_m186_no_real_device_certificate',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;
  late WaffraFreshModulesRepository repo;
  final now = DateTime.utc(2026, 10, 24, 13);
  const entity = <String, Object?>{
    'id': 'test-goal-186',
    'name': 'Synthetic laptop',
    'target': 2000.0,
    'saved': 145.5,
  };
  const schedule = <String, Object?>{
    'id': 'm186-utilities',
    'title': 'Monthly utility',
    'amount': 125.0,
    'income': false,
    'day': 24,
    'startAt': '2026-01-01T00:00:00',
    'active': true,
  };
  const category = <String, Object?>{
    'id': 'm186-main',
    'name': 'Main',
    'budget': 700.0,
    'income': false,
    'parentId': '',
  };

  Future<void> seed(
    WaffraFinanceModule module,
    Map<String, Object?> source,
  ) async {
    await store.transaction(() async {
      await repo.save(module, source);
      final original = await snapshot.read();
      final key = WaffraVerifiedModuleUiGuard.activeKey(module);
      await snapshot.commit(
        expectedGeneration: original.generation,
        fullFinanceSnapshot: <String, Object?>{
          ...original.values,
          key: jsonEncode(<Map<String, Object?>>[source]),
        },
      );
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    temp = await Directory.systemTemp.createTemp('m186-module-verified-');
    store = WaffraEncryptedStore.openAt(
      File('${temp.path}/lab.sqlite'),
      key: 'm186-synthetic-nonproduction-disposable-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final baseline = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: store, snapshot: snapshot, experimentalEnabled: true,
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
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _SyntheticActivatedSource(),
      encryptedSession: WaffraEncryptedFinanceSession(
        experimentalEnabled: true,
        bridge: WaffraVerifiedEncryptedFinanceBridge(
          snapshot: snapshot,
          cutoverJournal: journal,
          writerDirectory: temp,
          experimentalEnabled: true,
          allWritersRoutedVerified: true,
          secureKeyVerified: true,
        ),
      ),
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
    repo = WaffraFreshModulesRepository(
      store: store, experimentalEnabled: true,
    );
  });

  tearDown(() async {
    await store.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M186 verified goal delete/read/undo resets only saved balance', () async {
    await seed(WaffraFinanceModule.goals, entity);
    final first = await authority.load(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    WaffraVerifiedModuleUiGuard.requireUnchanged(
      activeRaw: first.finance.getString('waffra_goals_v24'),
      selected: Map<String, dynamic>.from(entity),
    );
    final removed = await authority.deleteVerifiedModuleToRecycle(
      baseline: first, module: WaffraFinanceModule.goals,
      entityId: 'test-goal-186', now: now, userConfirmed: true,
    );
    expect(jsonDecode(removed.finance.getString('waffra_goals_v24')!),
        isEmpty);
    final trash = await authority.listVerifiedDeletedModules(
      WaffraFinanceModule.goals,
    );
    expect(trash.keys, contains('test-goal-186'));
    final wrappers = WaffraVerifiedModuleUiGuard.verifiedTrash(
      module: WaffraFinanceModule.goals,
      trashRaw: removed.finance.getString('waffra_deleted_goals_v1'),
      encryptedExpiries: trash,
    );
    expect((wrappers.single['goal'] as Map)['saved'], 145.5);
    final restored = await authority.restoreVerifiedDeletedModule(
      baseline: removed, module: WaffraFinanceModule.goals,
      entityId: 'test-goal-186',
      now: now.add(const Duration(hours: 1)),
    );
    final rows = jsonDecode(restored.finance.getString('waffra_goals_v24')!)
        as List<dynamic>;
    expect((rows.single as Map)['saved'], 0.0);
    expect((await repo.list(WaffraFinanceModule.goals)).single['saved'], 0.0);
    expect(await authority.listVerifiedDeletedModules(WaffraFinanceModule.goals),
        isEmpty);
  });

  test('M186 category budget zero after verified source restore', () async {
    await seed(WaffraFinanceModule.categories, category);
    final start = await authority.load(
      route: WaffraFinanceRoute.categoryCreateEditDeleteRestore,
    );
    final deleted = await authority.deleteVerifiedModuleToRecycle(
      baseline: start, module: WaffraFinanceModule.categories,
      entityId: 'm186-main', now: now, userConfirmed: true,
    );
    final restored = await authority.restoreVerifiedDeletedModule(
      baseline: deleted, module: WaffraFinanceModule.categories,
      entityId: 'm186-main',
      now: now.add(const Duration(minutes: 30)),
    );
    final rows = jsonDecode(restored.finance.getString('waffra_categories_v24')!)
        as List<dynamic>;
    expect((rows.single as Map)['budget'], 0.0);
  });

  test('M186 recurring recovery remains paused and never creates entries',
      () async {
    await seed(WaffraFinanceModule.recurring, schedule);
    final before = await authority.load(
      route: WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    );
    final deleted = await authority.deleteVerifiedModuleToRecycle(
      baseline: before, module: WaffraFinanceModule.recurring,
      entityId: 'm186-utilities', now: now, userConfirmed: true,
    );
    final after = await authority.restoreVerifiedDeletedModule(
      baseline: deleted, module: WaffraFinanceModule.recurring,
      entityId: 'm186-utilities',
      now: now.add(const Duration(hours: 1)),
    );
    final rows = jsonDecode(after.finance.getString('waffra_recurring_v24')!)
        as List<dynamic>;
    expect((rows.single as Map)['active'], false);
    expect(after.ledgerRaw, '[]');
  });

  test('M186 legacy source cannot reach encrypted module delete/undo', () async {
    final authorityWithoutKey = WaffraVerifiedFinanceAuthority(
      sourceGuard: _SyntheticActivatedSource(),
    );
    await seed(WaffraFinanceModule.goals, entity);
    final baseline = await authority.load(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    final old = await snapshot.read();
    await expectLater(
      authorityWithoutKey.deleteVerifiedModuleToRecycle(
        baseline: baseline, module: WaffraFinanceModule.goals,
        entityId: 'test-goal-186', now: now, userConfirmed: true,
      ), throwsStateError);
    await expectLater(
      authority.deleteVerifiedModuleToRecycle(
        baseline: baseline, module: WaffraFinanceModule.goals,
        entityId: 'test-goal-186', now: now, userConfirmed: false,
      ), throwsStateError);
    expect((await snapshot.read()).digest, old.digest);
  });

  test('M186 stale module read and malformed UI cannot erase typed SQL',
      () async {
    await seed(WaffraFinanceModule.goals, entity);
    final selected = await authority.load(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
    );
    final after = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: after.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...after.values,
        'waffra_monthly_budget_v1': 600.0,
      },
    );
    final current = await snapshot.read();
    await expectLater(authority.deleteVerifiedModuleToRecycle(
      baseline: selected, module: WaffraFinanceModule.goals,
      entityId: 'test-goal-186', now: now, userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, current.digest);
    expect((await repo.list(WaffraFinanceModule.goals)).length, 1);
    final stale = <String, dynamic>{...entity, 'saved': 999.0};
    expect(() => WaffraVerifiedModuleUiGuard.requireUnchanged(
      activeRaw: jsonEncode([entity]), selected: stale,
    ), throwsStateError);
  });

  test('M186 trashed IDs are authoritative SQL witnesses, not UI strings',
      () async {
    final wrap = jsonEncode([
      <String, Object?>{
        'goal': entity, 'deletedAt': now.toIso8601String(),
      },
    ]);
    final verified = WaffraVerifiedModuleUiGuard.verifiedTrash(
      module: WaffraFinanceModule.goals, trashRaw: wrap,
      encryptedExpiries: <String, int>{
        'test-goal-186': now.add(const Duration(days: 30)).millisecondsSinceEpoch,
      },
    );
    expect(verified.length, 1);
    expect(() => WaffraVerifiedModuleUiGuard.verifiedTrash(
      module: WaffraFinanceModule.goals,
      trashRaw: wrap,
      encryptedExpiries: const <String, int>{'forged-id': 1},
    ), throwsStateError);
    expect(() => WaffraVerifiedModuleUiGuard.decodeRows(
      '[{"id":"dup"},{"id":"dup"}]',
    ), throwsStateError);
  });
}

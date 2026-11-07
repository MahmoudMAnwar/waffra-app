import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart' show WaffraNamedBudget;
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _M515VerifiedSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'm515_disposable_budget_test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore db;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;
  const route = WaffraFinanceRoute.challengeAndBudgetUpdate;
  const accountId = 'account:m515-bank';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    root = await Directory.systemTemp.createTemp('m515-budget-');
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/disposable.sqlite'),
      key: 'm515-disposable-verified-budget-vault-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await WaffraAccountsSchema.install(db);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: db, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final initial = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: db, snapshot: snapshot, experimentalEnabled: true,
    );
    final preflight = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: preflight.sourceSha256,
      targetDigest: initial.digest,
      now: DateTime.utc(2026, 11, 7),
    );
    await journal.verify(now: DateTime.utc(2026, 11, 7));
    await journal.acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 11, 7),
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _M515VerifiedSource(),
      encryptedSession: WaffraEncryptedFinanceSession(
        experimentalEnabled: true,
        bridge: WaffraVerifiedEncryptedFinanceBridge(
          snapshot: snapshot,
          cutoverJournal: journal,
          writerDirectory: root,
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
    await WaffraAccountsRepository(db: db, experimentalEnabled: true)
        .createAccount(
      id: accountId,
      name: 'Verified bank',
      kind: 'bank',
      openingMinor: 100000,
      createdIso: '2026-11-07T00:00:00Z',
      userConfirmed: true,
    );
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  String budgetJson(String id, {double cap = 1000, bool active = true}) =>
    jsonEncode(<Map<String, dynamic>>[
      WaffraNamedBudget(
        id: id,
        name: 'الميزانية الشهرية العامة',
        budget: cap,
        budgetActive: active,
        assignedAccountId: accountId,
      ).toJson(),
    ]);

  Map<String, Object> appCapture(String namedBudgets) => <String, Object>{
    'entries': '[]',
    'waffra_categories_v24': '[]',
    'waffra_named_budgets_v1': namedBudgets,
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

  Future<WaffraFinanceAuthorityRead> commitAsHome(
    WaffraFinanceAuthorityRead before,
    String raw,
  ) async {
    final captured = appCapture(raw);
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: route,
      source: before.source,
      snapshot: captured,
      witnessedValues: before.encryptedWitness?.snapshot.values,
    );
    expect(captured.keys.toSet(), <String>{
      'waffra_categories_v24', 'waffra_named_budgets_v1',
      'waffra_challenges_v1', 'waffra_monthly_budget_v1',
      'waffra_monthly_budget_enabled_v1',
    });
    return authority.saveCaptured(
      route: route,
      baseline: before,
      captured: captured,
    );
  }

  test('M515 budget with verified account persists across SQLCipher reload', () async {
    final before = await authority.load(route: route);
    final raw = budgetJson('budget:m515');
    final result = await commitAsHome(before, raw);
    final persisted = result.finance.getString('waffra_named_budgets_v1');
    expect(persisted, isNotNull);
    final rows = jsonDecode(persisted!) as List;
    expect(rows, hasLength(1));
    expect(rows.single['budget'], 1000);
    expect(rows.single['assignedAccountId'], accountId);
    expect(result.ledgerRaw, before.ledgerRaw);
    expect((await snapshot.read()).values['waffra_named_budgets_v1'], persisted);
    final cold = await authority.load(route: route);
    expect(cold.finance.getString('waffra_named_budgets_v1'), persisted);
    expect(cold.ledgerRaw, before.ledgerRaw);
    final accounts = await WaffraAccountsRepository(
      db: db, experimentalEnabled: true).balances();
    expect(accounts.singleWhere((account) => account.id == accountId)
      .balanceMinor, 100000);
  });

  test('M515 editing budget preserves other finance and prevents stale overwrite', () async {
    final first = await authority.load(route: route);
    final competing = await authority.load(route: route);
    await commitAsHome(first, budgetJson('budget:m515'));
    final saved = await authority.load(route: route);
    await expectLater(
      commitAsHome(competing, budgetJson('budget:stale')),
      throwsStateError,
    );
    expect((await snapshot.read()).values['waffra_named_budgets_v1'],
      saved.finance.getString('waffra_named_budgets_v1'));
    await commitAsHome(saved, budgetJson('budget:m515', cap: 1200, active: false));
    final finalState = await authority.load(route: route);
    final budgets = jsonDecode(
      finalState.finance.getString('waffra_named_budgets_v1')!) as List;
    expect(budgets, hasLength(1));
    expect(budgets.single['budget'], 1200);
    expect(budgets.single['budgetActive'], false);
    expect(budgets.single['assignedAccountId'], accountId);
    expect(finalState.ledgerRaw, first.ledgerRaw);
  });

  test('M515 unrelated transaction edit cannot piggyback on budget save', () async {
    final before = await authority.load(route: route);
    final captured = appCapture(budgetJson('budget:m515'))
      ..['entries'] = '[{"id":"unverified-expense"}]';
    expect(
      () => WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
        route: route, source: before.source,
        snapshot: captured,
        witnessedValues: before.encryptedWitness?.snapshot.values,
      ),
      throwsStateError,
    );
    expect((await snapshot.read()).values['waffra_named_budgets_v1'], isNull);
  });
}

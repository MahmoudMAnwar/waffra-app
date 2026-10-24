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

class _SyntheticSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_recurring_candidate_not_production',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore vault;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedFinanceSession session;
  late WaffraVerifiedFinanceAuthority authority;

  final recurring = <String, Object?>{
    'id': 'rent', 'title': 'Rent', 'category': 'Housing',
    'amount': 125.50, 'income': false, 'day': 24,
    'startAt': '2026-01-01T00:00:00', 'active': true,
  };
  Map<String, Object?> payment() => <String, Object?>{
    'id': 'rec_rent_2026_10',
    'title': 'Rent',
    'category': 'Housing',
    'amount': 125.50,
    'income': false,
    'date': '2026-10-24T12:00:00',
    'receiptPath': null,
  };

  Future<void> seedSchedule() async {
    final baseline = await session.loadForDashboardOrWidget();
    await session.saveChangedFields(
      baseline: baseline,
      changedValues: <String, Object?>{
        'waffra_recurring_v24': jsonEncode([recurring]),
      },
    );
  }

  Future<WaffraFinanceAuthorityRead> source() =>
      authority.load(route: WaffraFinanceRoute.recurringPostingAndPostponement);

  Future<WaffraFinanceAuthorityRead> pay(
    WaffraFinanceAuthorityRead loaded, {
    Map<String, Object?>? entry,
    bool confirmed = true,
    String postponed = '{}',
    Map<String, Object>? extras,
  }) {
    return authority.saveCaptured(
      route: WaffraFinanceRoute.recurringPostingAndPostponement,
      baseline: loaded,
      captured: <String, Object>{
        'entries': jsonEncode([entry ?? payment()]),
        'waffra_recurring_postponed_v1': postponed,
        ...?extras,
      },
      userConfirmed: confirmed,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    temp = await Directory.systemTemp.createTemp('waffra-m182-recurring-');
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/test.sqlite'),
      key: 'synthetic-disposable-only-m182',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final first = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: vault, snapshot: snapshot, experimentalEnabled: true,
    );
    final source = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: source.sourceSha256,
      targetDigest: first.digest,
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
        writerDirectory: temp,
        experimentalEnabled: true,
        allWritersRoutedVerified: true,
        secureKeyVerified: true,
      ),
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _SyntheticSource(),
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
    await seedSchedule();
  });

  tearDown(() async {
    await vault.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M182 confirmed paid recurring writes SQL+snapshot and clears postponement',
      () async {
    final sourceBefore = await source();
    final set = await session.saveChangedFields(
      baseline: sourceBefore.encryptedWitness!,
      changedValues: <String, Object?>{
        'waffra_recurring_postponed_v1':
            '{"rec_rent_2026_10":"2026-10-25"}',
      },
    );
    expect(set.values['waffra_recurring_postponed_v1'], contains('2026-10-25'));
    final loaded = await source();
    final result = await pay(loaded);
    expect(jsonDecode(result.ledgerRaw!), hasLength(1));
    expect(result.finance.getString('waffra_recurring_postponed_v1'), '{}');
    final rows = await vault.customSelect(
      'SELECT entry_id,amount_minor,receipt_count FROM fresh_finance_entries',
    ).get();
    expect(rows.length, 1);
    expect(rows.single.read<String>('entry_id'), 'rec_rent_2026_10');
    expect(rows.single.read<int>('amount_minor'), 12550);
    expect(rows.single.read<int>('receipt_count'), 0);
  });

  test('M182 preserves unrelated Widget hash added after Home baseline',
      () async {
    final loaded = await source();
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    await session.addSmsHashes([hash]);
    await pay(loaded);
    final saved = await snapshot.read();
    expect(saved.values['waffra_sms_hashes_v1'], [hash]);
    final typed = await vault.customSelect(
      'SELECT message_hash FROM fresh_finance_sms_hashes',
    ).get();
    expect(typed.single.read<String>('message_hash'), hash);
  });

  test('M182 unconfirmed Paid cannot create entry or remove postponement',
      () async {
    final old = await source();
    final current = await snapshot.read();
    await expectLater(pay(old, confirmed: false), throwsStateError);
    expect((await snapshot.read()).digest, current.digest);
    final rows = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(rows.read<int>('n'), 0);
  });

  test('M182 duplicate monthly recurring payment rejects repeated posting',
      () async {
    await pay(await source());
    final after = await snapshot.read();
    await expectLater(pay(await source()), throwsStateError);
    expect((await snapshot.read()).digest, after.digest);
    final rows = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(rows.read<int>('n'), 1);
  });

  test('M182 forged recurring amount or identity fails without partial commit',
      () async {
    final before = await source();
    final changed = Map<String, Object?>.from(payment())..['amount'] = 1.25;
    await expectLater(pay(before, entry: changed), throwsStateError);
    final wrongId = Map<String, Object?>.from(payment())
      ..['id'] = 'rec_not-rent_2026_10';
    await expectLater(pay(before, entry: wrongId), throwsStateError);
    final sql = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(sql.read<int>('n'), 0);
  });

  test('M182 schedule changes or stale postponement reject pending Paid',
      () async {
    final loaded = await source();
    await session.saveChangedFields(
      baseline: loaded.encryptedWitness!,
      changedValues: <String, Object?>{
        'waffra_recurring_postponed_v1': '{"rec_rent_2026_10":"2026-11-01"}',
      },
    );
    final before = await snapshot.read();
    await expectLater(pay(loaded), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
  });

  test('M182 rejecting other finance edits preserves unrelated balances',
      () async {
    final loaded = await source();
    final previous = await snapshot.read();
    await expectLater(pay(loaded,
      extras: <String, Object>{'waffra_monthly_budget_v1': 800.00},
    ), throwsStateError);
    expect((await snapshot.read()).digest, previous.digest);
  });

  test('M182 cannot post a receipt-bearing entry using scalar shortcut',
      () async {
    final loaded = await source();
    final record = Map<String, Object?>.from(payment())
      ..['receiptPath'] = '/data/synthetic.png';
    final previous = await snapshot.read();
    await expectLater(pay(loaded, entry: record), throwsStateError);
    expect((await snapshot.read()).digest, previous.digest);
  });

  test('M182 disabled encrypted finance session refuses a payment', () async {
    final witness = await session.loadForDashboardOrWidget();
    final disabled = WaffraEncryptedFinanceSession(bridge: session.bridge);
    await expectLater(disabled.commitRecurringPayment(
      baseline: witness, record: payment(), proposedPostponedJson: '{}',
      userConfirmed: true,
    ), throwsStateError);
  });
}

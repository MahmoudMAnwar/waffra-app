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

/// Synthetic source inspector: this fixture NEVER attests a real device,
/// secure OS key, production marker, independent migration or 24 live routes.
class _SyntheticEncryptedSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_encrypted_candidate_only',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory disposable;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedCutoverJournal journal;
  late WaffraEncryptedFinanceSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    disposable = await Directory.systemTemp.createTemp('waffra-m179-only-');
    store = WaffraEncryptedStore.openAt(
      File('${disposable.path}/candidate.sqlite'),
      key: 'disposable-test-only-encrypted-source',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final committed = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{
        'entries': '[]',
        'waffra_recurring_reminders_enabled_v1': false,
      },
    );
    journal = WaffraEncryptedCutoverJournal(
      store: store, snapshot: snapshot, experimentalEnabled: true,
    );
    final syntheticSource = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: syntheticSource.sourceSha256,
      targetDigest: committed.digest,
      now: DateTime.utc(2026, 10, 24),
    );
    await journal.verify(now: DateTime.utc(2026, 10, 24));
    await journal.acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 10, 24),
    );
    session = WaffraEncryptedFinanceSession(
      bridge: WaffraVerifiedEncryptedFinanceBridge(
        snapshot: snapshot,
        cutoverJournal: journal,
        writerDirectory: disposable,
        experimentalEnabled: true,
        allWritersRoutedVerified: true,
        secureKeyVerified: true,
      ),
      experimentalEnabled: true,
    );
  });

  tearDown(() async {
    await store.close();
    if (await disposable.exists()) {
      await disposable.delete(recursive: true);
    }
  });

  WaffraVerifiedFinanceAuthority syntheticAuthority() =>
      WaffraVerifiedFinanceAuthority(
        sourceGuard: _SyntheticEncryptedSource(),
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

  test('M179 writes recurring scalar durably via encrypted source', () async {
    final before = await snapshot.read();
    expect(before.values['waffra_recurring_reminders_enabled_v1'], false);
    await syntheticAuthority().setRecurringReminderPreference(true);
    final after = await snapshot.read();
    expect(after.generation, before.generation + 1);
    expect(after.values['waffra_recurring_reminders_enabled_v1'], true);
    expect(after.values['entries'], '[]');
    final preferences = await SharedPreferences.getInstance();
    // SQL is authoritative in this synthetic candidate, not legacy prefs.
    expect(preferences.containsKey('waffra_recurring_reminders_enabled_v1'),
        false);
  });

  test('M179 stale scalar cannot overwrite a later user toggle', () async {
    final stale = await session.loadForDashboardOrWidget();
    final current = await session.loadForDashboardOrWidget();
    await session.saveRecurringReminderPreference(
      baseline: current, enabled: true,
    );
    final committed = await snapshot.read();
    await expectLater(session.saveRecurringReminderPreference(
      baseline: stale, enabled: false,
    ), throwsStateError);
    final unchanged = await snapshot.read();
    expect(unchanged.generation, committed.generation);
    expect(unchanged.values['waffra_recurring_reminders_enabled_v1'], true);
  });

  test('M179 unrelated concurrent SMS hash survives reminder toggle',
      () async {
    final baseline = await session.loadForDashboardOrWidget();
    final hash = List<String>.filled(64, 'a').join();
    await session.addSmsHashes([hash]);
    final saved = await session.saveRecurringReminderPreference(
      baseline: baseline, enabled: true,
    );
    expect(saved.values['waffra_recurring_reminders_enabled_v1'], true);
    expect(saved.values['waffra_sms_hashes_v1'], [hash]);
  });

  test('M179 pending witness blocks encrypted scalar without legacy fallback',
      () async {
    final before = await snapshot.read();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(
      syntheticAuthority().setRecurringReminderPreference(true),
      throwsStateError,
    );
    final after = await snapshot.read();
    expect(after.digest, before.digest);
    expect(preferences.containsKey('waffra_recurring_reminders_enabled_v1'),
        false);
  });

  test('M179 disabled session refuses a scalar update', () async {
    final baseline = await session.loadForDashboardOrWidget();
    final disabled = WaffraEncryptedFinanceSession(
      bridge: session.bridge, experimentalEnabled: false,
    );
    await expectLater(disabled.saveRecurringReminderPreference(
      baseline: baseline, enabled: true,
    ), throwsStateError);
  });
}

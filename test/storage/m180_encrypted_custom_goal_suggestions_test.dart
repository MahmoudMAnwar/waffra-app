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

/// Test-only mocked SQLCipher activation report. Not an OS or release witness.
class _EncryptedFixtureSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_candidate_only',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late WaffraEncryptedStore database;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedFinanceSession session;
  late WaffraVerifiedFinanceAuthority authority;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    temporary = await Directory.systemTemp.createTemp('waffra-m180-');
    database = WaffraEncryptedStore.openAt(
      File('${temporary.path}/candidate.sqlite'),
      key: 'disposable-synthetic-key-no-production-data',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: database, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: database, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final stored = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: database, snapshot: snapshot, experimentalEnabled: true,
    );
    final source = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: source.sourceSha256,
      targetDigest: stored.digest,
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
        snapshot: snapshot, cutoverJournal: journal,
        writerDirectory: temporary, experimentalEnabled: true,
        allWritersRoutedVerified: true, secureKeyVerified: true,
      ),
      experimentalEnabled: true,
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _EncryptedFixtureSource(),
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
    await database.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('M180 fresh encrypted table persists one suggestion without prefs', () async {
    expect(await authority.loadCustomGoalSuggestions(), isEmpty);
    expect(await authority.addCustomGoalSuggestion('  My goal  '), isTrue);
    expect(await authority.loadCustomGoalSuggestions(), ['My goal']);
    final pref = await SharedPreferences.getInstance();
    expect(pref.containsKey('waffra_custom_goals_v1'), isFalse);
  });

  test('M180 deduplicates case-insensitive racing writers', () async {
    final results = await Future.wait([
      authority.addCustomGoalSuggestion('Home'),
      authority.addCustomGoalSuggestion('HOME'),
    ]);
    expect(results.where((x) => x).length, 1);
    expect((await authority.loadCustomGoalSuggestions()).length, 1);
  });

  test('M180 rejects empty or oversized suggestion before any write', () async {
    await expectLater(authority.addCustomGoalSuggestion('   '),
        throwsArgumentError);
    await expectLater(authority.addCustomGoalSuggestion(List<String>.filled(101, 'x').join()),
        throwsArgumentError);
    expect(await authority.loadCustomGoalSuggestions(), isEmpty);
  });

  test('M180 corrupted typed SQL sequence fails closed', () async {
    expect(await authority.addCustomGoalSuggestion('Valid'), isTrue);
    await database.customStatement(
      'UPDATE fresh_finance_custom_goals SET position=4 WHERE position=0',
    );
    await expectLater(authority.loadCustomGoalSuggestions(), throwsStateError);
    await expectLater(authority.addCustomGoalSuggestion('Other'),
        throwsStateError);
    final rows = await database.customSelect(
      'SELECT position,suggestion FROM fresh_finance_custom_goals',
    ).get();
    expect(rows.length, 1);
    expect(rows.single.read<String>('suggestion'), 'Valid');
  });

  test('M180 pending source marker blocks SQL and refuses legacy fallback', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(authority.addCustomGoalSuggestion('Blocked'),
        throwsStateError);
    await expectLater(authority.loadCustomGoalSuggestions(), throwsStateError);
    expect(prefs.containsKey('waffra_custom_goals_v1'), isFalse);
  });

  test('M180 default-off session cannot read or write custom goals', () async {
    final disabled = WaffraEncryptedFinanceSession(
      bridge: session.bridge, experimentalEnabled: false,
    );
    await expectLater(disabled.loadCustomGoalSuggestions(), throwsStateError);
    await expectLater(disabled.addCustomGoalSuggestion('Blocked'),
        throwsStateError);
  });
}

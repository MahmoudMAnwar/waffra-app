import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_production_finance_authority_binding.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

/// TEST-ONLY source fixture. It does not claim OS-key, physical phones or
/// release approval and may never be installed in lib/main.dart.
class _DisposableActiveSource extends WaffraProductionFinanceSourceGuard {
  const _DisposableActiveSource();

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'disposable_android_only',
  );
}

/// Every flag below is synthetic to exercise the real binder code path.
/// None of the synthetic flags may be persisted or treated as a release proof.
WaffraProductionCutoverEvidence _syntheticEvidence() =>
    WaffraProductionCutoverEvidence(
      storage: const WaffraCutoverReadinessReport(
        sourceDigest: 'emulator_only_not_physical',
        blockers: <String>[],
      ),
      routes: WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values.toSet(),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      ),
      accountDeletionVerified: true,
      privacyPolicyPublished: true,
      firebaseDataSafetyReviewed: true,
      crashReportingVerified: true,
      signedAndroidDeviceVerified: true,
      twoPhysicalDevicesRestoreVerified: true,
      expiryClockTrusted: true,
      explicitHumanApproval: true,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android disposable SQLCipher: Widget saves then Home cold-opens'
      ' identical entry and hash; wrong key fails closed', (tester) async {
    expect(Platform.isAndroid, isTrue);
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    final directory = await (await getTemporaryDirectory())
        .createTemp('waffra-disposable-live-binder-');
    const testKey = 'disposable-android-binder-test-key-not-real';
    const fingerprint =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const transactionId = 'test-widget-pos-one';
    final file = File(
      '${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}',
    );
    WaffraEncryptedStore? seed;
    WaffraProductionFinanceAuthorityBinding? widget;
    WaffraProductionFinanceAuthorityBinding? home;
    try {
      seed = WaffraEncryptedStore.openAt(file, key: testKey);
      await WaffraFreshEncryptedVaultBootstrap(
        store: seed, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: seed, experimentalEnabled: true,
      );
      await snapshot.initializeEmpty();
      final initial = await snapshot.commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
      );
      final journal = WaffraEncryptedCutoverJournal(
        store: seed, snapshot: snapshot, experimentalEnabled: true,
      );
      final legacyDigest = WaffraLegacyPreflight.inspect(
        const <String, Object?>{'entries': '[]'},
      ).sourceSha256;
      final time = DateTime.utc(2026, 10, 24);
      await journal.prepare(
        sourceDigest: legacyDigest, targetDigest: initial.digest, now: time,
      );
      await journal.verify(now: time);
      await journal.acknowledgeExternalActivation(
        externalMarkerVerified: true, allWritersRouted: true, now: time,
      );
      await seed.close();
      seed = null;

      Future<WaffraProductionFinanceAuthorityBinding> bind(
        WaffraFinanceRoute route, {String key = testKey}
      ) => WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        sourceGuard: const _DisposableActiveSource(),
        certifiedEvidence: _syntheticEvidence(),
        startupRoute: route,
        directoryProvider: () async => directory,
        secureKeyReader: () async => key,
      );

      // Test the exact Home/Widget binder classes, not the bridge directly.
      widget = await bind(WaffraFinanceRoute.widgetStartup);
      expect(widget.encrypted, isTrue);
      expect(
        (await widget.authority.load(route: WaffraFinanceRoute.widgetRead))
            .ledgerRaw,
        '[]',
      );

      final saved = await widget.authority.commitConfirmedSms(
        route: WaffraFinanceRoute.widgetSmsConfirmedSave,
        records: <Map<String, Object?>>[
          <String, Object?>{
            'id': transactionId,
            'title': 'Synthetic POS',
            'category': 'Groceries',
            'amount': 28.75,
            'income': false,
            'date': '2026-10-24T12:00:00',
            'receiptPath': null,
          },
        ],
        hashes: const [fingerprint],
        userConfirmed: true,
      );
      expect(saved.saved, 1);
      expect(saved.expenses, 1);
      expect(saved.expenseMinor, 2875);
      expect(saved.current.source,
          WaffraRuntimeFinanceBackend.verifiedEncrypted);
      await widget.close();
      widget = null;

      // Real SQLCipher disk reopen, not an in-memory fake.
      home = await bind(WaffraFinanceRoute.appStartup);
      final homeRead = await home.authority.load(
        route: WaffraFinanceRoute.dashboardRead,
      );
      expect(home.encrypted, isTrue);
      expect(homeRead.encryptedWitness, isNotNull);
      final ledger = jsonDecode(homeRead.ledgerRaw!) as List;
      expect(ledger, hasLength(1));
      expect(ledger.single['id'], transactionId);
      expect(ledger.single['amount'], 28.75);
      final widgetRead = await home.authority.load(
        route: WaffraFinanceRoute.widgetRead,
      );
      expect(widgetRead.encryptedWitness!.generation,
          homeRead.encryptedWitness!.generation);
      expect(widgetRead.ledgerRaw, homeRead.ledgerRaw);
      await home.close();
      home = null;

      // Database file is not an unencrypted SQLite database.
      final header = (await file.openRead(0, 16).toList())
          .expand((chunk) => chunk).toList();
      expect(header,
          isNot(<int>[83, 81, 76, 105, 116, 101, 32, 102,
                      111, 114, 109, 97, 116, 32, 51, 0]));

      // Key failure must never reopen an empty legacy balance.
      await expectLater(
        bind(WaffraFinanceRoute.appStartup, key: 'wrong-test-key'),
        throwsA(isA<Exception>()),
      );
      // Missing human/route evidence is blocked even if the vault exists.
      await expectLater(
        WaffraProductionFinanceAuthorityBinding.bind(
          legacy: const WaffraHomeFinancePersistence(),
          sourceGuard: const _DisposableActiveSource(),
          startupRoute: WaffraFinanceRoute.widgetStartup,
          directoryProvider: () async => directory,
          secureKeyReader: () async => testKey,
        ),
        throwsStateError,
      );
      final legacy = await SharedPreferences.getInstance();
      expect(legacy.getString('entries'), '[]',
          reason: 'The encrypted test must not overwrite legacy finance.');
    } finally {
      await home?.close();
      await widget?.close();
      await seed?.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

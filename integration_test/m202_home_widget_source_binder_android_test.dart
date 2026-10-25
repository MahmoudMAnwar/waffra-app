import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Variable;
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

/// Only a disposable test adapter: NEVER use it in production or treat these
/// synthetic release flags as verified independent real-device evidence.
class _DisposableActiveSource extends WaffraProductionFinanceSourceGuard {
  const _DisposableActiveSource();

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_android_test_source_only',
  );
}

WaffraProductionCutoverEvidence _testOnlyEvidence() =>
    WaffraProductionCutoverEvidence(
      storage: const WaffraCutoverReadinessReport(
        sourceDigest: 'throwaway_android_emulator_not_user_data',
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

  testWidgets('M202 Android: same durable SQLCipher authority for widget/Home,'
      ' bad key denied, no legacy fallthrough', (tester) async {
    expect(Platform.isAndroid, isTrue);
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    final directory = await (await getTemporaryDirectory())
        .createTemp('m202-disposable-finance-source-');
    final dbFile = File(
      '${directory.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}',
    );
    const testKey = 'm202-android-test-only-key-not-a-user-secret';
    const testHash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const entryId = 'm202-widget-synthetic-1';
    const homeId = 'm210-home-synthetic-2';
    const originalWidgetSms = 'شراء تجريبي\\nالمبلغ: 28.75 ريال\\n'
        'الوقت 2026-10-25 11:30\\nمرجع DEMO-100\\n'
        'Long note retained exactly; no real account details';
    const originalHomeSms = 'حوالة واردة تجريبية\\nمبلغ 16.50 SAR\\n'
        'مرجع DEMO-101\\nExtra newline\\nLast line';
    WaffraEncryptedStore? seed;
    WaffraProductionFinanceAuthorityBinding? widget;
    WaffraProductionFinanceAuthorityBinding? home;

    Future<WaffraProductionFinanceAuthorityBinding> bind(
      WaffraFinanceRoute startupRoute, {
      String key = testKey,
    }) => WaffraProductionFinanceAuthorityBinding.bind(
      legacy: const WaffraHomeFinancePersistence(),
      sourceGuard: const _DisposableActiveSource(),
      certifiedEvidence: _testOnlyEvidence(),
      startupRoute: startupRoute,
      directoryProvider: () async => directory,
      secureKeyReader: () async => key,
    );

    try {
      seed = WaffraEncryptedStore.openAt(dbFile, key: testKey);
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
      final initialDigest = WaffraLegacyPreflight.inspect(
        const <String, Object?>{'entries': '[]'},
      ).sourceSha256;
      final clock = DateTime.utc(2026, 10, 24);
      await journal.prepare(
        sourceDigest: initialDigest,
        targetDigest: initial.digest,
        now: clock,
      );
      await journal.verify(now: clock);
      await journal.acknowledgeExternalActivation(
        externalMarkerVerified: true,
        allWritersRouted: true,
        now: clock,
      );
      await seed.close();
      seed = null;

      // The real production binding class opens an actual pre-existing
      // SQLCipher file, validates cutover checkpoints, and owns its session.
      widget = await bind(WaffraFinanceRoute.widgetStartup);
      expect(widget.encrypted, isTrue);
      final widgetRead = await widget.authority.load(
        route: WaffraFinanceRoute.widgetRead,
      );
      expect(widgetRead.source, WaffraRuntimeFinanceBackend.verifiedEncrypted);
      expect(widgetRead.ledgerRaw, '[]');
      expect(widgetRead.encryptedWitness, isNotNull);

      final committed = await widget.authority.commitConfirmedSms(
        route: WaffraFinanceRoute.widgetSmsConfirmedSave,
        records: <Map<String, Object?>>[
          <String, Object?>{
            'id': entryId,
            'title': 'Synthetic offline widget test',
            'category': 'Groceries',
            'amount': 28.75,
            'income': false,
            'date': '2026-10-24T12:00:00',
            'receiptPath': null,
            'sourceType': 'sms',
            'notes': originalWidgetSms,
          },
        ],
        hashes: const <String>[testHash],
        userConfirmed: true,
      );
      expect(committed.saved, 1);
      expect(committed.expenses, 1);
      expect(committed.expenseMinor, 2875);
      final entries = jsonDecode(committed.current.ledgerRaw!) as List;
      expect(entries, hasLength(1));
      expect((entries.first as Map)['id'], entryId);
      expect((entries.first as Map)['notes'], originalWidgetSms);
      expect((entries.first as Map)['sourceType'], 'sms');
      expect(committed.originalSmsNotesOmittedOnLegacy, isFalse);
      expect(
        committed.current.finance.getStringList('waffra_sms_hashes_v1'),
        contains(testHash),
      );
      await widget.close();
      widget = null;

      // Reopen the actual SQLCipher file and verify the independent typed
      // SQL projection retained the same multiline SMS text, not just the
      // cached widget snapshot. Never log text or put it in an artifact.
      seed = WaffraEncryptedStore.openAt(dbFile, key: testKey);
      final typedWidget = await seed.customSelect(
        'SELECT source_json FROM fresh_finance_entries WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).getSingle();
      expect(
        (jsonDecode(typedWidget.read<String>('source_json')) as Map)['notes'],
        originalWidgetSms,
      );
      await seed.close();
      seed = null;

      // Fresh Home binding must read exactly the widget's durable bytes.
      home = await bind(WaffraFinanceRoute.appStartup);
      expect(home.encrypted, isTrue);
      final homeRead = await home.authority.load(
        route: WaffraFinanceRoute.dashboardRead,
      );
      expect(homeRead.source, WaffraRuntimeFinanceBackend.verifiedEncrypted);
      expect(homeRead.encryptedWitness, isNotNull);
      expect(homeRead.ledgerRaw, committed.current.ledgerRaw);
      expect(jsonDecode(homeRead.ledgerRaw!) as List, hasLength(1));
      expect(
        ((jsonDecode(homeRead.ledgerRaw!) as List).single as Map)['notes'],
        originalWidgetSms,
      );
      // Confirm a second synthetic SMS using the Home route. It MUST write
      // the same encrypted ledger and retain both full original notes.
      final homeCommitted = await home.authority.commitConfirmedSms(
        route: WaffraFinanceRoute.bulkSmsConfirmedSave,
        records: <Map<String, Object?>>[
          <String, Object?>{
            'id': homeId,
            'title': 'Synthetic Home income',
            'category': 'Salary',
            'amount': 16.50,
            'income': true,
            'date': '2026-10-25T12:00:00',
            'receiptPath': null,
            'sourceType': 'sms',
            'notes': originalHomeSms,
          },
        ],
        hashes: const <String>[
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ],
        userConfirmed: true,
      );
      expect(homeCommitted.saved, 1);
      expect(homeCommitted.income, 1);
      expect(homeCommitted.incomeMinor, 1650);
      expect(homeCommitted.originalSmsNotesOmittedOnLegacy, isFalse);
      final both = jsonDecode(homeCommitted.current.ledgerRaw!) as List;
      expect(both, hasLength(2));
      expect(
        (both.firstWhere((e) => (e as Map)['id'] == entryId) as Map)['notes'],
        originalWidgetSms,
      );
      expect(
        (both.firstWhere((e) => (e as Map)['id'] == homeId) as Map)['notes'],
        originalHomeSms,
      );
      final finalLedger = homeCommitted.current.ledgerRaw!;
      await home.close();
      home = null;

      // An invalid OS key MUST NOT silently return an empty legacy balance.
      // Failure must not create a new database or mutate old preferences.
      final sizeBefore = await dbFile.length();
      await expectLater(
        bind(WaffraFinanceRoute.appStartup, key: 'incorrect-test-only-key'),
        throwsA(anyOf(isA<Exception>(), isA<Error>())),
      );
      expect(await dbFile.length(), sizeBefore);
      final legacy = await SharedPreferences.getInstance();
      await legacy.reload();
      expect(legacy.getString('entries'), '[]');
      expect(legacy.getString('entries'), isNot(contains(originalWidgetSms)));
      expect(legacy.getString('entries'), isNot(contains(originalHomeSms)));

      // A present encrypted vault is still forbidden to launch without
      // independently verified release evidence, even on Android.
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

      // The correct key must still open the same ledger after the failure.
      home = await bind(WaffraFinanceRoute.appStartup);
      final recovered = await home.authority.load(
        route: WaffraFinanceRoute.dashboardRead,
      );
      expect(recovered.ledgerRaw, finalLedger);
      final recoveredRows = jsonDecode(recovered.ledgerRaw!) as List;
      expect(recoveredRows, hasLength(2));
      expect(
        (recoveredRows.firstWhere((e) => (e as Map)['id'] == entryId)
            as Map)['notes'], originalWidgetSms,
      );
      expect(
        (recoveredRows.firstWhere((e) => (e as Map)['id'] == homeId)
            as Map)['notes'], originalHomeSms,
      );
      await home.close();
      home = null;

      // A SQLCipher file must never be readable as a plaintext SQLite DB.
      final header = await dbFile.openRead(0, 16).toList();
      expect(header.expand((chunk) => chunk).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
      // No real SMS, user records, Firebase tokens or phone files were used.
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

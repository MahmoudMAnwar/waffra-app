import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_production_finance_authority_binding.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

class _FixedSourceGuard extends WaffraProductionFinanceSourceGuard {
  const _FixedSourceGuard(this.selected);
  final WaffraProductionFinanceSource selected;

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => WaffraProductionFinanceSourceReport(
    source: selected,
    reasonCode: 'synthetic_test_source',
  );
}

WaffraProductionCutoverEvidence syntheticApprovedEvidence({
  String sourceDigest = 'synthetic_not_hardware',
}) => WaffraProductionCutoverEvidence(
      storage: WaffraCutoverReadinessReport(
        sourceDigest: sourceDigest,
        blockers: const <String>[],
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Home uses guarded legacy when no active encrypted source exists',
      () async {
    final binding = await WaffraProductionFinanceAuthorityBinding.bind(
      legacy: const WaffraHomeFinancePersistence(),
      sourceGuard: const _FixedSourceGuard(
        WaffraProductionFinanceSource.guardedLegacy,
      ),
    );
    expect(binding.encrypted, isFalse);
    expect(binding.authority.encryptedSession, isNull);
    await binding.close();
  });

  test('Widget startup binds the identical audited legacy authority',
      () async {
    final binding = await WaffraProductionFinanceAuthorityBinding.bind(
      legacy: const WaffraHomeFinancePersistence(),
      sourceGuard: const _FixedSourceGuard(
        WaffraProductionFinanceSource.guardedLegacy,
      ),
      startupRoute: WaffraFinanceRoute.widgetStartup,
    );
    expect(binding.encrypted, isFalse);
    expect(binding.authority.audit.eligibleForIndependentReview, isFalse);
    await binding.close();
  });

  test('manual-recovery source never falls through to legacy', () async {
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        sourceGuard: const _FixedSourceGuard(
          WaffraProductionFinanceSource.manualRecoveryRequired,
        ),
      ),
      throwsStateError,
    );
  });

  test('an existing encrypted source cannot launch without release evidence',
      () async {
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        sourceGuard: const _FixedSourceGuard(
          WaffraProductionFinanceSource.encryptedRoutingRequired,
        ),
        startupRoute: WaffraFinanceRoute.widgetStartup,
      ),
      throwsStateError,
    );
  });

  test('an unapproved route cannot be used as a startup shortcut', () async {
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        sourceGuard: const _FixedSourceGuard(
          WaffraProductionFinanceSource.guardedLegacy,
        ),
        startupRoute: WaffraFinanceRoute.transactionEdit,
      ),
      throwsArgumentError,
    );
  });

  test('fake green evidence cannot invent missing encrypted database',
      () async {
    final dir = await Directory.systemTemp.createTemp('waffra-bind-negative-');
    try {
      await expectLater(
        WaffraProductionFinanceAuthorityBinding.bind(
          legacy: const WaffraHomeFinancePersistence(),
          sourceGuard: const _FixedSourceGuard(
            WaffraProductionFinanceSource.encryptedRoutingRequired,
          ),
          certifiedEvidence: syntheticApprovedEvidence(),
          directoryProvider: () async => dir,
          secureKeyReader: () async => 'synthetic-never-trusted-key',
        ),
        throwsStateError,
      );
      expect(dir.listSync(), isEmpty,
          reason: 'Binding must never create a new empty finance vault.');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('existing activated SQLCipher file binds real Home and Widget reads'
      ' under synthetic disposable source evidence only', () async {
    SharedPreferences.setMockInitialValues({
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    final dir = await Directory.systemTemp.createTemp('waffra-real-bind-');
    const key = 'disposable-home-widget-test-key-not-for-users';
    final file = File(
      dir.path + Platform.pathSeparator +
          WaffraEncryptedStore.encryptedDatabaseFilename,
    );
    final seed = WaffraEncryptedStore.openAt(file, key: key);
    try {
      await WaffraFreshEncryptedVaultBootstrap(
        store: seed, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: seed, experimentalEnabled: true,
      );
      await snapshot.initializeEmpty();
      final state = await snapshot.commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
      );
      final journal = WaffraEncryptedCutoverJournal(
        store: seed, snapshot: snapshot, experimentalEnabled: true,
      );
      final legacySource = WaffraLegacyPreflight.inspect(
        const <String, Object?>{'entries': '[]'},
      );
      await journal.prepare(
        sourceDigest: legacySource.sourceSha256,
        targetDigest: state.digest,
        now: DateTime.utc(2026, 10, 24),
      );
      await journal.verify(now: DateTime.utc(2026, 10, 24));
      await journal.acknowledgeExternalActivation(
        externalMarkerVerified: true,
        allWritersRouted: true,
        now: DateTime.utc(2026, 10, 24),
      );
    } finally {
      await seed.close();
    }
    try {
      // Passing every Boolean audit field is insufficient if the approval
      // belongs to another legacy source. No vault may be bound in that case.
      await expectLater(
        WaffraProductionFinanceAuthorityBinding.bind(
          legacy: const WaffraHomeFinancePersistence(),
          sourceGuard: const _FixedSourceGuard(
            WaffraProductionFinanceSource.encryptedRoutingRequired,
          ),
          certifiedEvidence: syntheticApprovedEvidence(),
          directoryProvider: () async => dir,
          secureKeyReader: () async => key,
        ),
        throwsStateError,
      );
      final sourceDigest = WaffraLegacyPreflight.inspect(
        const <String, Object?>{'entries': '[]'},
      ).sourceSha256;
      // A matching finance witness still cannot open the vault when the
      // Android secure-storage reader has lost its key or supplies a wrong
      // key. These are simulated readers, NOT Android hardware evidence.
      for (final badKey in <String?>[null, 'incorrect-test-only-key']) {
        await expectLater(
          WaffraProductionFinanceAuthorityBinding.bind(
            legacy: const WaffraHomeFinancePersistence(),
            sourceGuard: const _FixedSourceGuard(
              WaffraProductionFinanceSource.encryptedRoutingRequired,
            ),
            certifiedEvidence: syntheticApprovedEvidence(
              sourceDigest: sourceDigest,
            ),
            directoryProvider: () async => dir,
            secureKeyReader: () async => badKey,
          ),
          throwsA(anything),
        );
        expect(await file.exists(), isTrue,
            reason: 'Failed key recovery must not remove existing vault.');
      }
      for (final route in <WaffraFinanceRoute>[
        WaffraFinanceRoute.appStartup,
        WaffraFinanceRoute.widgetStartup,
      ]) {
        final binding = await WaffraProductionFinanceAuthorityBinding.bind(
          legacy: const WaffraHomeFinancePersistence(),
          sourceGuard: const _FixedSourceGuard(
            WaffraProductionFinanceSource.encryptedRoutingRequired,
          ),
          certifiedEvidence: syntheticApprovedEvidence(sourceDigest: sourceDigest),
          startupRoute: route,
          directoryProvider: () async => dir,
          secureKeyReader: () async => key,
        );
        try {
          expect(binding.encrypted, isTrue);
          final finance = await binding.authority.load(
            route: route == WaffraFinanceRoute.appStartup
                ? WaffraFinanceRoute.dashboardRead
                : WaffraFinanceRoute.widgetRead,
          );
          expect(finance.encryptedWitness, isNotNull);
          expect(finance.ledgerRaw, '[]');
        } finally {
          await binding.close();
        }
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('an encrypted approval cannot silently downgrade to legacy',
      () async {
    await expectLater(
      WaffraProductionFinanceAuthorityBinding.bind(
        legacy: const WaffraHomeFinancePersistence(),
        sourceGuard: const _FixedSourceGuard(
          WaffraProductionFinanceSource.guardedLegacy,
        ),
        certifiedEvidence: syntheticApprovedEvidence(),
      ),
      throwsStateError,
    );
  });
}

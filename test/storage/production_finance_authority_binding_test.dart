import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
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

WaffraProductionCutoverEvidence syntheticApprovedEvidence() =>
    WaffraProductionCutoverEvidence(
      storage: const WaffraCutoverReadinessReport(
        sourceDigest: 'synthetic_not_hardware',
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

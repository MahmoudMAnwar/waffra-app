import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

void main() {
  const legacy = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
  const active = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'encrypted_source_probe_failed',
  );

  WaffraFinanceRouteAudit approvedAudit() => WaffraFinanceRouteAudit(
    verifiedRoutes: WaffraFinanceRoute.values.toSet(),
    keyRecoveryVerified: true, twoWitnessRecoveryVerified: true,
    receiptRollbackVerified: true, backupRestoreVerified: true,
    crossEngineLockVerified: true, legacyParityVerified: true,
  );

  test('M100 all 24 finance routes preserve verified legacy authority', () {
    final contract = WaffraRuntimeFinanceRouteContract(
      source: legacy, audit: approvedAudit(),
    );
    for (final route in WaffraFinanceRoute.values) {
      expect(contract.requireRoute(route),
          WaffraRuntimeFinanceBackend.guardedLegacy);
    }
  });

  test('M100 mixed legacy and SQL activation witnesses always refuse writes',
      () {
    for (final sql in [true, false]) {
      for (final external in [true, false]) {
        if (!sql && !external) continue;
        final contract = WaffraRuntimeFinanceRouteContract(
          source: legacy, audit: approvedAudit(),
          encryptedSqlWitnessActive: sql,
          externalSourceWitnessActive: external,
        );
        for (final route in WaffraFinanceRoute.values) {
          expect(() => contract.requireRoute(route),
              throwsA(isA<StateError>()));
        }
      }
    }
  });

  test('M100 pending cutover never falls back to an empty finance source',
      () {
    final contract = WaffraRuntimeFinanceRouteContract(
      source: recovery, audit: approvedAudit(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    expect(() => contract.requireAllLiveRoutes(),
        throwsA(isA<StateError>()));
  });

  test('M100 missing ANY live route individually blocks encrypted activation',
      () {
    for (final missing in WaffraFinanceRoute.values) {
      final audit = WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values.toSet()..remove(missing),
        keyRecoveryVerified: true, twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true, backupRestoreVerified: true,
        crossEngineLockVerified: true, legacyParityVerified: true,
      );
      final contract = WaffraRuntimeFinanceRouteContract(
        source: active, audit: audit,
        encryptedSqlWitnessActive: true,
        externalSourceWitnessActive: true,
        verifiedKeyRecoveryInDevice: true,
      );
      expect(() => contract.requireAllLiveRoutes(),
          throwsA(isA<StateError>()), reason: missing.name);
    }
  });

  test('M100 each mandatory key and two witness is independently required',
      () {
    for (var i = 0; i < 3; i++) {
      final contract = WaffraRuntimeFinanceRouteContract(
        source: active, audit: approvedAudit(),
        encryptedSqlWitnessActive: i != 0,
        externalSourceWitnessActive: i != 1,
        verifiedKeyRecoveryInDevice: i != 2,
      );
      expect(() => contract.requireRoute(
        WaffraFinanceRoute.widgetSmsConfirmedSave,
      ), throwsA(isA<StateError>()));
    }
  });

  test('M100 ready candidate selects encryption only after all 24 proofs',
      () {
    final contract = WaffraRuntimeFinanceRouteContract(
      source: active, audit: approvedAudit(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
    );
    for (final route in WaffraFinanceRoute.values) {
      expect(contract.requireRoute(route),
          WaffraRuntimeFinanceBackend.verifiedEncrypted);
    }
  });
}

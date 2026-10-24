import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

/// Contract-level safety only. Passing these tests is NOT evidence that
/// 24 real finance operations ran against SQLCipher on a physical Android.
void main() {
  const active = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'active_source_requires_external_proof',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'source_disagreement',
  );

  WaffraFinanceRouteAudit audit({
    Set<WaffraFinanceRoute>? routes,
    bool key = true,
    bool witnesses = true,
    bool receipts = true,
    bool restore = true,
    bool lock = true,
    bool parity = true,
  }) => WaffraFinanceRouteAudit(
    verifiedRoutes: routes ?? WaffraFinanceRoute.values.toSet(),
    keyRecoveryVerified: key,
    twoWitnessRecoveryVerified: witnesses,
    receiptRollbackVerified: receipts,
    backupRestoreVerified: restore,
    crossEngineLockVerified: lock,
    legacyParityVerified: parity,
  );

  WaffraRuntimeFinanceRouteContract contract({
    WaffraProductionFinanceSourceReport? source,
    WaffraFinanceRouteAudit? evidence,
    bool sql = true,
    bool external = true,
    bool key = true,
  }) => WaffraRuntimeFinanceRouteContract(
    source: source ?? active,
    audit: evidence ?? audit(),
    encryptedSqlWitnessActive: sql,
    externalSourceWitnessActive: external,
    verifiedKeyRecoveryInDevice: key,
  );

  test('M201 exact 24-route preflight inventory is still independently gated',
      () {
    expect(WaffraFinanceRoute.values.length, 24);
    expect(WaffraFinanceRoute.values.toSet().length, 24);
    const unproven = WaffraFinanceRouteAudit();
    expect(unproven.eligibleForIndependentReview, isFalse);
    expect(unproven.blockers.where((b) =>
        b.startsWith('unverified_route_')).length, 24);
  });

  for (final absent in WaffraFinanceRoute.values) {
    test('M201 absent ${absent.name} blocks EVERY encrypted route, not just one',
        () {
      final allowed = WaffraFinanceRoute.values.toSet()..remove(absent);
      final selector = contract(evidence: audit(routes: allowed));
      for (final route in WaffraFinanceRoute.values) {
        expect(() => selector.requireRoute(route), throwsStateError,
          reason: 'Missing ${absent.name} must block ${route.name} too');
      }
    });
  }

  test('M201 missing each independent key/receipt/restore/lock/parity witness'
      ' blocks the entire 24-route encrypted candidate', () {
    final missing = <WaffraFinanceRouteAudit>[
      audit(key: false), audit(witnesses: false),
      audit(receipts: false), audit(restore: false),
      audit(lock: false), audit(parity: false),
    ];
    for (final evidence in missing) {
      expect(evidence.eligibleForIndependentReview, isFalse);
      for (final route in WaffraFinanceRoute.values) {
        expect(() => contract(evidence: evidence).requireRoute(route),
            throwsStateError, reason: route.name);
      }
    }
  });

  test('M201 missing either SQL pointer, external pointer, or device key'
      ' blocks all routes even under a synthetically complete audit', () {
    final cases = [
      contract(sql: false), contract(external: false), contract(key: false),
    ];
    for (final selector in cases) {
      for (final route in WaffraFinanceRoute.values) {
        expect(() => selector.requireRoute(route), throwsStateError);
      }
    }
  });

  test('M201 corrupt or pending cutover never reads any of 24 routes', () {
    final selector = contract(source: recovery);
    for (final route in WaffraFinanceRoute.values) {
      expect(() => selector.requireRoute(route), throwsStateError);
    }
  });

  test('M201 synthetic complete audit only tests selection, not real activity',
      () {
    final selector = contract();
    for (final route in WaffraFinanceRoute.values) {
      expect(selector.requireRoute(route),
          WaffraRuntimeFinanceBackend.verifiedEncrypted);
    }
    // No runtime receipt, biometrics, Android UI, phone, or backup is
    // created by this source-selection test. Do not mark a route certified.
  });
}

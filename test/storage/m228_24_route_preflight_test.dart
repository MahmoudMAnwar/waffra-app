import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_finance_24_route_preflight.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

void main() {
  const active = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_active_only',
  );
  const legacy = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'guarded_legacy',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'corrupt_checkpoint',
  );
  const preflight = WaffraFinance24RoutePreflight();

  WaffraFinanceRouteAudit testOnlyAudit({
    Set<WaffraFinanceRoute>? routes,
    bool restore = true,
  }) => WaffraFinanceRouteAudit(
    verifiedRoutes: routes ?? WaffraFinanceRoute.values.toSet(),
    keyRecoveryVerified: true,
    twoWitnessRecoveryVerified: true,
    receiptRollbackVerified: true,
    backupRestoreVerified: restore,
    crossEngineLockVerified: true,
    legacyParityVerified: true,
  );

  WaffraFinance24RoutePreflightReport probe(
    WaffraProductionFinanceSourceReport source, {
    WaffraFinanceRouteAudit? audit,
    bool sql = true,
    bool external = true,
    bool key = true,
  }) => preflight.inspect(
    source: source,
    audit: audit ?? testOnlyAudit(),
    encryptedSqlWitnessActive: sql,
    externalSourceWitnessActive: external,
    verifiedKeyRecoveryInDevice: key,
  );

  test('M228 audits all 24 distinct routes, not a manually curated subset', () {
    expect(WaffraFinanceRoute.values.length, 24);
    expect(WaffraFinanceRoute.values.toSet().length, 24);
    final candidate = probe(active);
    expect(candidate.routes.keys.toSet(), WaffraFinanceRoute.values.toSet());
    expect(candidate.allContractsAcceptEncrypted, isTrue);
    // All-green synthetic flags are NOT actual release authorization.
    expect(candidate.productionCutoverAuthorized, isFalse);
  });

  test('M228 never labels normal guarded legacy as verified SQLCipher', () {
    final report = probe(legacy, sql: false, external: false);
    expect(report.allContractsAcceptEncrypted, isFalse);
    expect(report.routes.values.toSet(),
        {WaffraRouteSourceOutcome.guardedLegacy});
    expect(report.blockers, contains('source_guardedLegacy'));
  });

  test('M228 a pending/corrupt cutover blocks all 24 routes', () {
    final report = probe(recovery);
    expect(report.allContractsAcceptEncrypted, isFalse);
    expect(report.routes.values.toSet(), {WaffraRouteSourceOutcome.blocked});
    expect(report.blockers, contains('source_manualRecoveryRequired'));
  });

  for (final missing in WaffraFinanceRoute.values) {
    test('M228 missing ${missing.name} blocks the entire encrypted source', () {
      final claimed = WaffraFinanceRoute.values.toSet()..remove(missing);
      final result = probe(active, audit: testOnlyAudit(routes: claimed));
      expect(result.missingAuditRoutes, [missing]);
      expect(result.allContractsAcceptEncrypted, isFalse);
      expect(result.routes.values.toSet(), {WaffraRouteSourceOutcome.blocked});
      expect(result.blockers, contains('unverified_route_${missing.name}'));
    });
  }

  test('M228 no key, missing external witness or SQL witness blocks all', () {
    for (final result in [
      probe(active, key: false),
      probe(active, sql: false),
      probe(active, external: false),
      probe(active, audit: testOnlyAudit(restore: false)),
    ]) {
      expect(result.allContractsAcceptEncrypted, isFalse);
      expect(result.routes.values.toSet(), {WaffraRouteSourceOutcome.blocked});
    }
  });

  test('M228 reports are immutable; another engine cannot edit fake evidence', () {
    final result = probe(active);
    expect(() => result.routes.clear(), throwsUnsupportedError);
    expect(() => result.missingAuditRoutes.clear(), throwsUnsupportedError);
    expect(() => result.blockers.add('false_approval'), throwsUnsupportedError);
  });
}

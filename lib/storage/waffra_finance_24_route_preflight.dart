import 'waffra_production_finance_routing_gate.dart';
import 'waffra_production_finance_source_guard.dart';
import 'waffra_runtime_finance_route_contract.dart';

/// A source-contract preflight for the EXACT 24 live app/widget finance routes.
///
/// This is a read-only structural check. It cannot independently certify
/// on-device writers, an OS key, historical attachment bytes, backup recovery
/// or permission to activate a new authoritative source.
enum WaffraRouteSourceOutcome { guardedLegacy, encryptedContract, blocked }

class WaffraFinance24RoutePreflightReport {
  const WaffraFinance24RoutePreflightReport({
    required this.routes,
    required this.missingAuditRoutes,
    required this.blockers,
  });

  final Map<WaffraFinanceRoute, WaffraRouteSourceOutcome> routes;
  final List<WaffraFinanceRoute> missingAuditRoutes;
  final List<String> blockers;

  /// Structural route selection only; does NOT certify Android deployment.
  bool get allContractsAcceptEncrypted =>
      routes.length == WaffraFinanceRoute.values.length &&
      missingAuditRoutes.isEmpty &&
      blockers.isEmpty &&
      routes.values.every(
        (value) => value == WaffraRouteSourceOutcome.encryptedContract,
      );

  /// Never equate generated/synthetic flags with production authorization.
  bool get productionCutoverAuthorized => false;
}

class WaffraFinance24RoutePreflight {
  const WaffraFinance24RoutePreflight();

  WaffraFinance24RoutePreflightReport inspect({
    required WaffraProductionFinanceSourceReport source,
    required WaffraFinanceRouteAudit audit,
    bool encryptedSqlWitnessActive = false,
    bool externalSourceWitnessActive = false,
    bool verifiedKeyRecoveryInDevice = false,
  }) {
    // Verify every route in the canonical enum, not a maintained subset.
    final selector = WaffraRuntimeFinanceRouteContract(
      source: source,
      audit: audit,
      encryptedSqlWitnessActive: encryptedSqlWitnessActive,
      externalSourceWitnessActive: externalSourceWitnessActive,
      verifiedKeyRecoveryInDevice: verifiedKeyRecoveryInDevice,
    );
    final results = <WaffraFinanceRoute, WaffraRouteSourceOutcome>{};
    for (final route in WaffraFinanceRoute.values) {
      try {
        final selected = selector.requireRoute(route);
        results[route] = selected == WaffraRuntimeFinanceBackend.verifiedEncrypted
            ? WaffraRouteSourceOutcome.encryptedContract
            : WaffraRouteSourceOutcome.guardedLegacy;
      } on StateError {
        results[route] = WaffraRouteSourceOutcome.blocked;
      }
    }
    final missing = List<WaffraFinanceRoute>.unmodifiable(
      WaffraFinanceRoute.values.where(
        (route) => !audit.verifiedRoutes.contains(route),
      ),
    );
    final problems = <String>{
      ...audit.blockers,
      if (source.source != WaffraProductionFinanceSource.encryptedRoutingRequired)
        'source_${source.source.name}',
      if (!encryptedSqlWitnessActive) 'encrypted_sql_witness_missing',
      if (!externalSourceWitnessActive) 'external_source_witness_missing',
      if (!verifiedKeyRecoveryInDevice) 'device_key_recovery_missing',
    };
    return WaffraFinance24RoutePreflightReport(
      routes: Map<WaffraFinanceRoute, WaffraRouteSourceOutcome>.unmodifiable(
        results,
      ),
      missingAuditRoutes: missing,
      blockers: List<String>.unmodifiable(problems.toList()..sort()),
    );
  }
}

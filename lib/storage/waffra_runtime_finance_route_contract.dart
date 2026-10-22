import 'waffra_production_finance_routing_gate.dart';
import 'waffra_production_finance_source_guard.dart';

enum WaffraRuntimeFinanceBackend { guardedLegacy, verifiedEncrypted }

/// Explicit source agreement for EACH app + Android widget finance route.
/// The security audit is independent of any UI toggle or Firebase login.
/// No preferences, keys, checkpoints or files are modified by this class.
class WaffraRuntimeFinanceRouteContract {
  const WaffraRuntimeFinanceRouteContract({
    required this.source,
    required this.audit,
    this.encryptedSqlWitnessActive = false,
    this.externalSourceWitnessActive = false,
    this.verifiedKeyRecoveryInDevice = false,
  });

  final WaffraProductionFinanceSourceReport source;
  final WaffraFinanceRouteAudit audit;
  final bool encryptedSqlWitnessActive;
  final bool externalSourceWitnessActive;
  final bool verifiedKeyRecoveryInDevice;

  WaffraRuntimeFinanceBackend requireRoute(WaffraFinanceRoute route) {
    switch (source.source) {
      case WaffraProductionFinanceSource.guardedLegacy:
        // Even a green audit cannot switch a user without both durable
        // witnesses. Legacy remains authoritative until the cutover exists.
        if (encryptedSqlWitnessActive || externalSourceWitnessActive) {
          throw StateError(
            'Unreconciled SQLCipher source witness on ${route.name}.',
          );
        }
        return WaffraRuntimeFinanceBackend.guardedLegacy;
      case WaffraProductionFinanceSource.encryptedRoutingRequired:
        if (!encryptedSqlWitnessActive ||
            !externalSourceWitnessActive ||
            !verifiedKeyRecoveryInDevice ||
            !audit.eligibleForIndependentReview ||
            !audit.verifiedRoutes.contains(route)) {
          throw StateError(
            'Encrypted route ${route.name} is not proven safe.',
          );
        }
        return WaffraRuntimeFinanceBackend.verifiedEncrypted;
      case WaffraProductionFinanceSource.manualRecoveryRequired:
        // Absolutely no fall-through to a second empty/new finance source.
        throw StateError(
          'Manual finance recovery required before ${route.name}.',
        );
    }
  }

  void requireAllLiveRoutes() {
    for (final route in WaffraFinanceRoute.values) {
      requireRoute(route);
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_production_finance_source_guard.dart';

/// Every finance-affecting surface that must be proven to use ONE authoritative
/// source before a future SQLCipher activation. The list is intentionally
/// exhaustive for the current app and standalone Android widget engines.
///
/// Adding a new finance route requires adding an enum value: the readiness
/// audit will then fail closed until that route is independently verified.
enum WaffraFinanceRoute {
  appStartup,
  widgetStartup,
  dashboardRead,
  widgetRead,
  manualTransactionSave,
  bulkSmsConfirmedSave,
  widgetSmsConfirmedSave,
  transactionEdit,
  transactionDeleteAndUndo,
  deleteAllTransactions,
  categoryCatalogInstall,
  categoryCreateEditDeleteRestore,
  goalCreateEditDeleteRestore,
  recurringCreateEditDeleteRestore,
  recurringPostingAndPostponement,
  challengeAndBudgetUpdate,
  merchantRulesAndSmsHashes,
  receiptCopyAndAttach,
  receiptView,
  receiptRemoveAndRollback,
  widgetBalanceRefresh,
  backupExport,
  backupRestore,
  fullFinanceReset,
}

/// Read-only route inventory. This is an audit gate, NOT an activation API:
/// satisfying it only permits an independent release review.
class WaffraFinanceRouteAudit {
  const WaffraFinanceRouteAudit({
    this.verifiedRoutes = const <WaffraFinanceRoute>{},
    this.keyRecoveryVerified = false,
    this.twoWitnessRecoveryVerified = false,
    this.receiptRollbackVerified = false,
    this.backupRestoreVerified = false,
    this.crossEngineLockVerified = false,
    this.legacyParityVerified = false,
  });

  /// Evidence must be collected by real app/widget/restore integration tests,
  /// not by a user preference or the presence of a Firebase login.
  final Set<WaffraFinanceRoute> verifiedRoutes;
  final bool keyRecoveryVerified;
  final bool twoWitnessRecoveryVerified;
  final bool receiptRollbackVerified;
  final bool backupRestoreVerified;
  final bool crossEngineLockVerified;
  final bool legacyParityVerified;

  List<String> get blockers {
    final result = <String>[
      for (final route in WaffraFinanceRoute.values)
        if (!verifiedRoutes.contains(route)) 'unverified_route_${route.name}',
      if (!keyRecoveryVerified) 'encrypted_key_recovery_unverified',
      if (!twoWitnessRecoveryVerified) 'two_witness_recovery_unverified',
      if (!receiptRollbackVerified) 'receipt_rollback_unverified',
      if (!backupRestoreVerified) 'backup_restore_unverified',
      if (!crossEngineLockVerified) 'app_widget_lock_unverified',
      if (!legacyParityVerified) 'legacy_finance_parity_unverified',
    ];
    return List<String>.unmodifiable(result);
  }

  /// Even an empty blocker list DOES NOT switch storage or authorize cloud
  /// upload. A separate durable source selector and release gate are required.
  bool get eligibleForIndependentReview => blockers.isEmpty;
}

/// Shared startup routing boundary for HomeScreen and the Android widget.
///
/// Current production routes may ONLY access the guarded legacy source.
/// Active/pending/inconsistent SQLCipher evidence must block both engines,
/// never silently fall back to an empty balance or create a replacement key.
/// No method here writes finance, source markers, or Firebase documents.
class WaffraProductionFinanceRoutingGate {
  const WaffraProductionFinanceRoutingGate({
    this.sourceGuard = const WaffraProductionFinanceSourceGuard(),
  });

  final WaffraProductionFinanceSourceGuard sourceGuard;

  static void requireGuardedLegacyReport({
    required WaffraProductionFinanceSourceReport report,
    required WaffraFinanceRoute route,
  }) {
    if (!report.legacyIsSafe) {
      // Reason codes and route names contain no user data, file paths or keys.
      throw StateError(
        'Finance route ${route.name} blocked: ${report.reasonCode}',
      );
    }
  }

  Future<void> requireGuardedLegacy({
    required WaffraFinanceRoute route,
    SharedPreferences? preferences,
  }) async {
    final report = await sourceGuard.inspect(preferences: preferences);
    requireGuardedLegacyReport(report: report, route: route);
  }
}

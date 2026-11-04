import 'waffra_fresh_encrypted_vault_bootstrap.dart';
import 'waffra_production_finance_routing_gate.dart';

/// A dry-run decision for an ENCRYPTED-ONLY future fresh-install release.
///
/// A verdict never opens a database, writes a key, sets the activation
/// marker, switches Home/Widget, or deletes any legacy finance data.
///
/// After the 24 live routes and the complete portable backup have been
/// independently verified, the future first-run coordinator may ask for
/// a fresh SQLCipher vault. Until then a clean install MUST fail closed,
/// not silently use an unencrypted finance source.
enum WaffraMandatoryFirstRunAction {
  provisionEncryptedCandidateOnly,
  verifyExistingEncryptedVault,
  preserveAndReviewLegacy,
  manualRecoveryRequired,
  blockedUntilEncryptedRuntimeCertified,
}

class WaffraMandatoryFirstRunVerdict {
  const WaffraMandatoryFirstRunVerdict({
    required this.action,
    required this.reasonCode,
  });

  final WaffraMandatoryFirstRunAction action;
  final String reasonCode;

  bool get mayPrepareNewVault =>
      action == WaffraMandatoryFirstRunAction.provisionEncryptedCandidateOnly;

  /// This is ALWAYS false: only the separate authenticated cutover journal
  /// and final release gate are allowed to select the active finance source.
  bool get mayAutomaticallyActivate => false;
}

class WaffraMandatoryEncryptedFirstRunGate {
  const WaffraMandatoryEncryptedFirstRunGate();

  WaffraMandatoryFirstRunVerdict evaluate({
    required Map<String, Object?> existingPreferences,
    required bool encryptedVaultFileExists,
    required bool activationMarkerExists,
    required bool secureKeyExists,
    required bool independentWriterMayBeActive,
    required Set<WaffraFinanceRoute> verifiedLiveRoutes,
    required bool portableAllDomainsAndReceiptsVerified,
    required bool homeWidgetCrossEngineLockVerified,
  }) {
    // An OS key without its encrypted vault, or a vault without its key, must
    // never be interpreted as a brand-new account. Either case can indicate
    // interrupted provisioning and needs recovery, not data replacement.
    if (secureKeyExists != encryptedVaultFileExists) {
      return const WaffraMandatoryFirstRunVerdict(
        action: WaffraMandatoryFirstRunAction.manualRecoveryRequired,
        reasonCode: 'encrypted_key_file_mismatch',
      );
    }
    final state = const WaffraFirstRunClassifier().decide(
      existingPreferences: existingPreferences,
      encryptedVaultFileExists: encryptedVaultFileExists,
      activationMarkerExists: activationMarkerExists,
      independentWriterMayBeActive: independentWriterMayBeActive,
    );
    switch (state) {
      case WaffraFirstRunDecision.inconsistentState:
        return const WaffraMandatoryFirstRunVerdict(
          action: WaffraMandatoryFirstRunAction.manualRecoveryRequired,
          reasonCode: 'ambiguous_source_or_pending_writer',
        );
      case WaffraFirstRunDecision.legacyNeedsReview:
        return const WaffraMandatoryFirstRunVerdict(
          action: WaffraMandatoryFirstRunAction.preserveAndReviewLegacy,
          reasonCode: 'legacy_finance_or_account_exists',
        );
      case WaffraFirstRunDecision.encryptedVaultAlreadyPresent:
        return const WaffraMandatoryFirstRunVerdict(
          action: WaffraMandatoryFirstRunAction.verifyExistingEncryptedVault,
          reasonCode: 'requires_os_key_sql_and_owner_witness_verification',
        );
      case WaffraFirstRunDecision.freshCandidate:
        if (verifiedLiveRoutes.length != WaffraFinanceRoute.values.length ||
            !verifiedLiveRoutes.containsAll(WaffraFinanceRoute.values) ||
            !portableAllDomainsAndReceiptsVerified ||
            !homeWidgetCrossEngineLockVerified) {
          return const WaffraMandatoryFirstRunVerdict(
            action: WaffraMandatoryFirstRunAction
                .blockedUntilEncryptedRuntimeCertified,
            reasonCode: 'mandatory_encrypted_source_not_release_ready',
          );
        }
        return const WaffraMandatoryFirstRunVerdict(
          action: WaffraMandatoryFirstRunAction.provisionEncryptedCandidateOnly,
          reasonCode: 'empty_install_candidate_requires_atomic_activation',
        );
    }
  }
}

/// Explicit cloud upload boundary for Waffra's sensitive financial data.
///
/// This file has no Firebase import, no network access and is not wired to UI.
/// Even a successful Google sign-in MUST NOT enable cloud synchronization.
enum WaffraSyncDisabledReason {
  noUserConsent,
  noAuthenticatedUser,
  unlinkedLocalVault,
  noRecoveryEncryptionKey,
  regionNotVerified,
  securityRulesNotVerified,
  localMigrationUnverified,
}

class WaffraSyncEligibility {
  const WaffraSyncEligibility({
    required this.explicitUserConsent,
    required this.firebaseUid,
    required this.linkedVaultOwnerUid,
    required this.recoveryKeyAvailable,
    required this.dammamDatabaseVerified,
    required this.securityRulesVerified,
    required this.localMigrationVerified,
  });

  final bool explicitUserConsent;
  final String? firebaseUid;
  final String? linkedVaultOwnerUid;
  final bool recoveryKeyAvailable;
  final bool dammamDatabaseVerified;
  final bool securityRulesVerified;
  final bool localMigrationVerified;

  /// A permanent fail-closed check required before any future upload.
  WaffraSyncDisabledReason? get disabledReason {
    if (!explicitUserConsent) return WaffraSyncDisabledReason.noUserConsent;
    if (firebaseUid == null || firebaseUid!.trim().isEmpty) {
      return WaffraSyncDisabledReason.noAuthenticatedUser;
    }
    if (linkedVaultOwnerUid != firebaseUid) {
      return WaffraSyncDisabledReason.unlinkedLocalVault;
    }
    if (!localMigrationVerified) {
      return WaffraSyncDisabledReason.localMigrationUnverified;
    }
    if (!recoveryKeyAvailable) {
      return WaffraSyncDisabledReason.noRecoveryEncryptionKey;
    }
    if (!dammamDatabaseVerified) {
      return WaffraSyncDisabledReason.regionNotVerified;
    }
    if (!securityRulesVerified) {
      return WaffraSyncDisabledReason.securityRulesNotVerified;
    }
    return null;
  }

  bool get maySync => disabledReason == null;
}

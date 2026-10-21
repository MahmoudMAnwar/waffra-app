import 'legacy_snapshot_preflight.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

enum WaffraFinanceSourceStatus {
  /// May initialize a completely new encrypted vault AFTER a writer freeze.
  freshCandidate,
  /// Existing SharedPreferences are the current, unswitched source.
  legacyPreferences,
  /// Both activation witnesses match and encrypted vault is readable.
  encryptedVault,
  /// No silent fallback: requires explicit safe reconciliation/restore.
  recoveryRequired,
}

class WaffraFinanceSourceEvidence {
  const WaffraFinanceSourceEvidence({
    required this.preferences,
    required this.encryptedFileExists,
    required this.encryptedKeyReadable,
    required this.encryptedSqlActivationVerified,
    this.cooperatingWritersFrozen = false,
    this.encryptedFeatureAvailable = false,
  });

  final Map<String, Object?> preferences;
  final bool encryptedFileExists;
  final bool encryptedKeyReadable;
  final bool encryptedSqlActivationVerified;

  /// Only true if dashboard, widget, SMS and recurring writers are prevented
  /// from writing an obsolete source during transition.
  final bool cooperatingWritersFrozen;

  /// Whether this app release actually supports the encrypted finance source.
  final bool encryptedFeatureAvailable;
}

/// Pure, fail-closed policy. Does not mutate preferences, create keys/files,
/// perform Firebase requests or activate the shipped Waffra app.
///
/// The authoritative activated state needs TWO witnesses: the external
/// preferences pointer and an independently verified SQL activation row.
/// If they disagree, never let an old dashboard overwrite newer encrypted
/// transactions as though a fresh install were being initialized.
class WaffraFinanceSourceCutoverPolicy {
  const WaffraFinanceSourceCutoverPolicy();

  static const preferenceActivationKey =
      'waffra_encrypted_finance_active_v1';

  WaffraFinanceSourceStatus resolve(WaffraFinanceSourceEvidence evidence) {
    final p = evidence.preferences;
    final markerExists = p.containsKey(preferenceActivationKey);
    final marker = p[preferenceActivationKey];
    if (markerExists && marker != true) {
      return WaffraFinanceSourceStatus.recoveryRequired;
    }

    if (evidence.encryptedFileExists || markerExists ||
        evidence.encryptedSqlActivationVerified) {
      if (!evidence.encryptedFileExists ||
          !markerExists ||
          !evidence.encryptedKeyReadable ||
          !evidence.encryptedSqlActivationVerified ||
          !evidence.encryptedFeatureAvailable) {
        return WaffraFinanceSourceStatus.recoveryRequired;
      }
      // Once active, the encrypted vault remains authoritative. It is normal
      // to retain read-only legacy prefs for rollback and comparison.
      return WaffraFinanceSourceStatus.encryptedVault;
    }

    if (evidence.encryptedKeyReadable) {
      // A key with no DB or source marker is ambiguous and could be a lost
      // encrypted database. Do not overwrite with a new empty finance file.
      return WaffraFinanceSourceStatus.recoveryRequired;
    }

    final financialKeys = WaffraLegacyPreflight.allKeys.toSet();
    final knownLegacy = p.keys.any(financialKeys.contains);
    if (knownLegacy) return WaffraFinanceSourceStatus.legacyPreferences;

    final classified = const WaffraFirstRunClassifier().decide(
      existingPreferences: p,
      encryptedVaultFileExists: false,
      activationMarkerExists: false,
      independentWriterMayBeActive: !evidence.cooperatingWritersFrozen,
    );
    return switch (classified) {
      WaffraFirstRunDecision.freshCandidate =>
        WaffraFinanceSourceStatus.freshCandidate,
      WaffraFirstRunDecision.legacyNeedsReview =>
        WaffraFinanceSourceStatus.legacyPreferences,
      _ => WaffraFinanceSourceStatus.recoveryRequired,
    };
  }
}

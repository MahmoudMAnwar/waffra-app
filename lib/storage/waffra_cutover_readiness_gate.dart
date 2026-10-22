import 'legacy_snapshot_preflight.dart';

/// Immutable evidence required before a production source switch.
/// A successful migration rehearsal alone is deliberately insufficient.
class WaffraCutoverReadinessEvidence {
  const WaffraCutoverReadinessEvidence({
    required this.legacySnapshot,
    required this.encryptedFinanceMatches,
    required this.receiptBytesMatch,
    required this.allFinanceWritersRouted,
    required this.widgetWriterRouted,
    required this.encryptedKeyRecoverable,
    required this.twoWitnessActivationRecoverable,
    required this.androidColdStartVerified,
    required this.backupRestoreVerified,
  });

  final Map<String, Object?> legacySnapshot;
  final bool encryptedFinanceMatches;
  final bool receiptBytesMatch;
  final bool allFinanceWritersRouted;
  final bool widgetWriterRouted;
  final bool encryptedKeyRecoverable;
  final bool twoWitnessActivationRecoverable;
  final bool androidColdStartVerified;
  final bool backupRestoreVerified;
}

class WaffraCutoverReadinessReport {
  const WaffraCutoverReadinessReport({
    required this.sourceDigest,
    required this.blockers,
  });

  final String sourceDigest;
  final List<String> blockers;
  bool get canActivate => blockers.isEmpty;
}

/// Pure, read-only release gate: does not create a database, flip source
/// pointers, delete legacy records, or enable Firebase.
class WaffraCutoverReadinessGate {
  const WaffraCutoverReadinessGate();

  WaffraCutoverReadinessReport inspect(
    WaffraCutoverReadinessEvidence evidence,
  ) {
    final preflight = WaffraLegacyPreflight.inspect(evidence.legacySnapshot);
    final blockers = <String>[];
    if (!preflight.canStage) blockers.add('legacy_finance_invalid');
    if (!evidence.encryptedFinanceMatches) {
      blockers.add('encrypted_finance_parity_missing');
    }
    if (!evidence.receiptBytesMatch) {
      blockers.add('encrypted_receipt_byte_parity_missing');
    }
    if (!evidence.allFinanceWritersRouted) {
      blockers.add('dashboard_sms_recurring_writers_not_routed');
    }
    if (!evidence.widgetWriterRouted) {
      blockers.add('widget_writer_not_routed');
    }
    if (!evidence.encryptedKeyRecoverable) {
      blockers.add('encrypted_key_recovery_not_verified');
    }
    if (!evidence.twoWitnessActivationRecoverable) {
      blockers.add('two_witness_activation_recovery_missing');
    }
    if (!evidence.androidColdStartVerified) {
      blockers.add('android_cold_start_not_verified');
    }
    if (!evidence.backupRestoreVerified) {
      blockers.add('backup_restore_not_verified');
    }
    return WaffraCutoverReadinessReport(
      sourceDigest: preflight.sourceSha256,
      blockers: List.unmodifiable(blockers),
    );
  }
}

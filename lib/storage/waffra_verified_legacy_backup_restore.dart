import 'dart:convert';

import 'legacy_snapshot_preflight.dart';
import 'waffra_home_finance_persistence.dart';

class WaffraVerifiedLegacyRestoreResult {
  const WaffraVerifiedLegacyRestoreResult({
    required this.sourceChecksum,
    required this.transactionCount,
    required this.ledgerRaw,
  });

  final String sourceChecksum;
  final int transactionCount;
  final String ledgerRaw;
}

/// Strict, opt-in legacy backup restore until the SQLCipher primary source is
/// activated. Builds ONE full financial intent and runs it through the same
/// recoverable app/widget lock as real dashboard and SMS writes.
///
/// Unlike updating HomeScreen's in-memory lists before persist(), a failed
/// preflight/conflict never modifies live widgets or any finance preference.
/// This does not use Firebase, create SQLCipher files or touch profile settings.
class WaffraVerifiedLegacyBackupRestore {
  const WaffraVerifiedLegacyBackupRestore({required this.persistence});

  final WaffraHomeFinancePersistence persistence;

  static const requiredFinanceKeys = <String>{
    'entries',
    'waffra_categories_v24',
    'waffra_goals_v24',
    'waffra_recurring_v24',
    'waffra_challenges_v1',
    'waffra_deleted_categories_v1',
    'waffra_deleted_goals_v1',
    'waffra_deleted_recurring_v1',
    'waffra_recurring_postponed_v1',
    'waffra_monthly_budget_v1',
    'waffra_monthly_budget_enabled_v1',
    'waffra_learned_merchants_v1',
    'waffra_sms_hashes_v1',
    'waffra_recurring_reminders_enabled_v1',
  };

  static bool _hasReceiptPaths(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return true;
    for (final row in decoded) {
      if (row is! Map) return true;
      final receipt = row['receiptPath'];
      if (receipt != null && receipt != '') return true;
    }
    return false;
  }

  Future<WaffraVerifiedLegacyRestoreResult> restore({
    required Map<String, Object> finance,
    required String? expectedLedgerRaw,
    required String? expectedWidgetRevision,
  }) async {
    if (finance.keys.toSet().difference(requiredFinanceKeys).isNotEmpty ||
        requiredFinanceKeys.difference(finance.keys.toSet()).isNotEmpty) {
      throw ArgumentError('Backup restore must include every finance field.');
    }
    final captured = <String, Object>{
      for (final entry in finance.entries)
        entry.key: entry.value is List<String>
            ? List<String>.unmodifiable(entry.value as List<String>)
            : entry.value,
    };
    final audit = WaffraLegacyPreflight.inspect(captured);
    if (!audit.canStage) {
      throw StateError('Backup finance failed integrity preflight.');
    }
    final rawLedger = captured['entries'];
    if (rawLedger is! String || _hasReceiptPaths(rawLedger)) {
      // Old JSON-only backups preserve absolute receiptPath strings but NOT
      // their bytes. Never report a recovered invoice unless its bytes are
      // separately copied/verified by the encrypted receipt installer.
      throw StateError('Backup receipt files need verified byte restoration.');
    }
    final entries = jsonDecode(rawLedger) as List;
    final persisted = await persistence.saveLegacy(
      snapshot: Map<String, Object>.unmodifiable(captured),
      expectedLedgerRaw: expectedLedgerRaw,
      expectedWidgetRevision: expectedWidgetRevision,
    );
    return WaffraVerifiedLegacyRestoreResult(
      sourceChecksum: audit.sourceSha256,
      transactionCount: entries.length,
      ledgerRaw: persisted,
    );
  }
}

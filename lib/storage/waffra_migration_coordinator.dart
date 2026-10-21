import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_financial_snapshot.dart';
import 'legacy_snapshot_preflight.dart' as detailed;
import 'waffra_encrypted_store.dart';
import 'waffra_ledger_projection.dart';

/// The migration stays DISABLED: no production caller is wired to this class.
/// The user-facing app still reads/writes its existing SharedPreferences ledger.
///
/// Caller MUST implement a writer barrier that suspends all finance mutations
/// (UI, widget, SMS, recurring engine) before invoking [stageWithBarrier].
/// This is a staging-only pipeline and must never set a cutover marker.
class WaffraMigrationCoordinator {
  const WaffraMigrationCoordinator({
    required this.openEncryptedStore,
    required this.acquireWriteBarrier,
    required this.releaseWriteBarrier,
  });

  final Future<WaffraEncryptedStore> Function() openEncryptedStore;
  final Future<void> Function() acquireWriteBarrier;
  final Future<void> Function() releaseWriteBarrier;

  /// Captures only the known legacy financial keys. No side effects.
  /// This *must* be called under the write barrier; otherwise a concurrent
  /// SharedPreferences write could change one key during snapshotting.
  static Future<Map<String, Object?>> readPreferencesSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final result = <String, Object?>{};
    for (final key in detailed.WaffraLegacyPreflight.allKeys) {
      if (!keys.contains(key)) continue;
      final value = prefs.get(key);
      // SharedPreferences getStringList returns a mutable collection. Copy it
      // before releasing the write barrier.
      result[key] = value is List<String>
          ? List<String>.unmodifiable(value)
          : value;
    }
    return result;
  }

  /// Stages a *copy* in encrypted SQLite; verifies ledger totals, receipts,
  /// source checksums and restart-safe projection. No Firebase calls and no
  /// replacement or deletion of the legacy source.
  ///
  /// Any error is propagated to the test caller. The barrier is always
  /// released; a failed import never marks the new DB as active.
  Future<WaffraShadowMigrationSummary> stageWithBarrier({
    required String vaultId,
  }) async {
    WaffraEncryptedStore? database;
    await acquireWriteBarrier();
    try {
      final snapshot = await readPreferencesSnapshot();
      final preflight = const WaffraLegacySnapshotInspector().inspect(snapshot);
      final strict = detailed.WaffraLegacyPreflight.inspect(snapshot);
      if (!preflight.canStage || !strict.canStage) {
        throw StateError('Legacy snapshot validation blocked migration staging.');
      }
      database = await openEncryptedStore();
      final staged = await database.stageSnapshot(vaultId, snapshot);
      final relational = await database.buildRelationalProjection(vaultId);
      if (staged.sourceSha256 != relational.sourceSha256 ||
          staged.recordCount != relational.stagedSourceRecords ||
          staged.incomeMinor != relational.incomeMinor ||
          staged.expenseMinor != relational.expenseMinor ||
          staged.receiptReferences != relational.receiptReferences) {
        throw StateError('Shadow-to-relational financial parity mismatch.');
      }
      return WaffraShadowMigrationSummary(
        sourceChecksum: staged.sourceSha256,
        totalRecords: staged.recordCount,
        entries: relational.ledgerEntries,
        verified: true,
      );
    } finally {
      try {
        await database?.close();
      } finally {
        await releaseWriteBarrier();
      }
    }
  }
}

class WaffraShadowMigrationSummary {
  const WaffraShadowMigrationSummary({
    required this.sourceChecksum,
    required this.totalRecords,
    required this.entries,
    required this.verified,
  });
  final String sourceChecksum;
  final int totalRecords;
  final int entries;
  final bool verified;

  /// Safe for automated test logs: no money totals, transaction names,
  /// identifiers, message hashes, receipt paths or source checksums.
  Map<String, Object> get redactedTelemetry => {
        'legacy_shadow_staging_ok': verified,
        'has_entries': entries > 0,
      };
}

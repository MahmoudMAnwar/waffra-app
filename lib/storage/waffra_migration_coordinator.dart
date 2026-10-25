import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_financial_snapshot.dart';
import 'legacy_snapshot_preflight.dart' as detailed;
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_ledger_projection.dart';

/// Migration is staging-only: no production caller activates this candidate.
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
  /// Called only while a verified writer lease is held, AFTER journal
  /// recovery and a native preferences reload. Deep-copy mutable string lists
  /// so a second Flutter engine cannot change the staged snapshot in memory.
  static Map<String, Object?> copyCurrentFinancialPreferences(
      SharedPreferences prefs) {
    final keys = prefs.getKeys();
    final result = <String, Object?>{};
    for (final key in detailed.WaffraLegacyPreflight.allKeys) {
      if (!keys.contains(key)) continue;
      final value = prefs.get(key);
      result[key] = value is List<String>
          ? List<String>.unmodifiable(value)
          : value;
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  static Future<Map<String, Object?>> readPreferencesSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    // The widget has its own Flutter engine. A cached copy can be stale even
    // if all Dart-side writers are quiescent.
    await prefs.reload();
    return copyCurrentFinancialPreferences(prefs);
  }

  /// Use this concrete native Home/Widget lease for staging. It recovers
  /// pending legacy journals and verifies the source BEFORE entering here,
  /// and holds the SAME inter-engine file lock through SQL import and parity
  /// checks. It never marks SQLCipher as active or deletes the source.
  Future<WaffraShadowMigrationSummary> stageWithSharedWriterLease({
    required WaffraLegacyFinanceWriterCoordinator legacyWriter,
    required String vaultId,
  }) => legacyWriter.withCurrentPreferences((current) async {
    // Do NOT call SharedPreferences.getInstance() again outside this lock.
    final frozen = copyCurrentFinancialPreferences(current);
    return _stageFrozenCopy(vaultId: vaultId, snapshot: frozen);
  });

  Future<WaffraShadowMigrationSummary> _stageFrozenCopy({
    required String vaultId,
    required Map<String, Object?> snapshot,
  }) async {
    final preflight = const WaffraLegacySnapshotInspector().inspect(snapshot);
    final strict = detailed.WaffraLegacyPreflight.inspect(snapshot);
    if (!preflight.canStage || !strict.canStage) {
      throw StateError('Legacy snapshot validation blocked migration staging.');
    }
    WaffraEncryptedStore? database;
    try {
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
      await database?.close();
    }
  }

  /// Legacy fixture/test entry: the caller must supply an independently
  /// verified writer freeze that spans BOTH engines, not an in-process mutex.
  /// Real Waffra should use stageWithSharedWriterLease above instead.
  Future<WaffraShadowMigrationSummary> stageWithBarrier({
    required String vaultId,
  }) async {
    await acquireWriteBarrier();
    try {
      final snapshot = await readPreferencesSnapshot();
      // Await the entire encrypted staging and parity validation BEFORE
      // releasing the caller-supplied writer freeze in finally.
      return await _stageFrozenCopy(vaultId: vaultId, snapshot: snapshot);
    } finally {
      await releaseWriteBarrier();
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

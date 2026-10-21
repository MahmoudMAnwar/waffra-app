import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_legacy_widget_commit_journal.dart';
import 'waffra_live_legacy_finance_guard.dart';

/// The live HomeScreen's finance persistence boundary.
///
/// M57 routes the EXISTING dashboard through one guarded entry point.
/// SharedPreferences remains authoritative: this class neither opens a
/// SQLCipher vault nor sets cutover markers or activates Firebase. The future
/// encrypted implementation must be selected only after all app/widget/SMS
/// writers share an independently verified, crash-safe source selector.
class WaffraHomeFinancePersistence {
  const WaffraHomeFinancePersistence({
    this.coordinator = const WaffraLegacyFinanceWriterCoordinator(),
  });

  final WaffraLegacyFinanceWriterCoordinator coordinator;

  /// Read only the current legacy source. Recover an interrupted widget
  /// commit under the native writer lock BEFORE taking the screen snapshot.
  /// A cutover marker fails closed rather than displaying old or empty data.
  Future<WaffraFinanceReadView> loadLegacy(
    SharedPreferences preferences,
  ) async {
    await const WaffraLiveLegacyFinanceGuard()
        .requireLegacySource(preferences);
    if (preferences.containsKey(WaffraLegacyWidgetCommitJournal.pendingKey)) {
      await coordinator.withCurrentPreferences((_) async {});
      await preferences.reload();
    }
    await const WaffraLiveLegacyFinanceGuard()
        .requireLegacySource(preferences, reload: false);
    return WaffraFinanceReadView.fromLegacy(preferences);
  }

  /// Persist the screen's already-captured batch without mixing in profile
  /// settings. The cross-engine lock checks the exact ledger and widget
  /// revision before ANY field is changed. Returns the committed ledger
  /// witness for the next queued HomeScreen write.
  ///
  /// This preserves legacy behavior; SharedPreferences multi-key writes are
  /// not atomic. SQLCipher source activation is deliberately not implemented.
  Future<String> saveLegacy({
    required Map<String, Object> snapshot,
    required String? expectedLedgerRaw,
    required String? expectedWidgetRevision,
  }) async {
    final captured = Map<String, Object>.unmodifiable(snapshot);
    if (captured.keys.toSet().difference(
      WaffraLegacyPreflight.allKeys.toSet(),
    ).isNotEmpty) {
      throw ArgumentError('Attempted to save non-financial preference keys.');
    }
    final entries = captured['entries'];
    if (entries is! String) {
      throw ArgumentError('Screen ledger must be a JSON string.');
    }
    for (final entry in captured.entries) {
      final value = entry.value;
      if (value is! String && value is! double && value is! bool) {
        throw ArgumentError('Unsupported legacy financial value: ${entry.key}');
      }
    }
    await coordinator.withCurrentPreferences((preferences) async {
      WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
        preferences,
        expectedRaw: expectedLedgerRaw,
        expectedWidgetRevision: expectedWidgetRevision,
      );
      for (final entry in captured.entries) {
        final value = entry.value;
        final bool saved;
        if (value is String) {
          saved = await preferences.setString(entry.key, value);
        } else if (value is double) {
          saved = await preferences.setDouble(entry.key, value);
        } else if (value is bool) {
          saved = await preferences.setBool(entry.key, value);
        } else {
          throw StateError('Unsupported legacy financial value.');
        }
        if (!saved) {
          throw StateError('Failed to persist financial preference batch.');
        }
      }
    });
    return entries;
  }
}

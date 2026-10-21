import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';

/// Immutable financial read + independent widget revision captured while
/// holding the same cross-engine lock used for financial writes.
class WaffraHomeFinanceLoaded {
  const WaffraHomeFinanceLoaded({
    required this.finance,
    required this.widgetRevision,
  });

  final WaffraFinanceReadView finance;
  final String? widgetRevision;

  String? get ledgerRaw => finance.getString('entries');
}

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

  /// Read finance plus widget revision under a single native writer lock.
  /// The coordinator replays a pending widget journal and blocks cutover
  /// markers before calling us, so this cannot mix before/after transactions.
  Future<WaffraHomeFinanceLoaded> loadWithWitness() =>
      coordinator.withCurrentPreferences((preferences) async {
        return WaffraHomeFinanceLoaded(
          finance: WaffraFinanceReadView.fromLegacy(preferences),
          widgetRevision:
              preferences.getString('waffra_widget_last_save_v1'),
        );
      });

  /// Retained for callers that only need the legacy finance value view.
  Future<WaffraFinanceReadView> loadLegacy(
    SharedPreferences preferences,
  ) async => (await loadWithWitness()).finance;

  /// Single guarded entry for all participating live writers (dashboard,
  /// widget SMS, catalog, dedupe and recurring settings). Callers must not
  /// take this lock recursively. The real coordinator recovers interrupted
  /// widget saves and rejects pending/enabled SQLCipher cutover.
  Future<T> withLegacyWriter<T>(
    Future<T> Function(SharedPreferences preferences) writer,
  ) => coordinator.withCurrentPreferences(writer);

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

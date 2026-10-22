import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_legacy_finance_batch_journal.dart';
import 'waffra_legacy_widget_commit_journal.dart';

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


class WaffraConfirmedLegacySmsResult {
  const WaffraConfirmedLegacySmsResult({
    required this.savedEntriesRaw,
    required this.savedHashes,
    required this.widgetRevision,
    required this.added,
    required this.savedIncome,
    required this.savedExpenses,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.skippedDuplicates,
  });
  final String savedEntriesRaw;
  final List<String> savedHashes;
  final String? widgetRevision;
  final int added, savedIncome, savedExpenses;
  final int incomeMinor, expenseMinor, skippedDuplicates;
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

  /// Custom saving-goal suggestions live beside the primary financial
  /// snapshot in legacy installs. They are included in verified SQLCipher
  /// staging, so all reads and writes must share the native app/widget lock.
  /// Never touch arbitrary profile or bank settings here.
  Future<List<String>> loadCustomGoalSuggestions() =>
      coordinator.withCurrentPreferences((prefs) async {
        if (!prefs.containsKey('waffra_custom_goals_v1')) {
          return const <String>[];
        }
        final value = prefs.getStringList('waffra_custom_goals_v1');
        if (value == null || value.length > 1000 ||
            value.any((name) => name.trim().isEmpty || name.length > 512)) {
          throw StateError('Saved custom goal suggestions are invalid.');
        }
        return List<String>.unmodifiable(value);
      });

  /// Atomically adds a custom suggestion without overwriting suggestions
  /// written by another app instance since the goal dialog opened. A future
  /// fully encrypted runtime will replace this one legacy-only adapter,
  /// not copy its SharedPreferences implementation into UI code.
  Future<bool> addCustomGoalSuggestion(String suggestedName) async {
    final name = suggestedName.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Custom savings goal name must be 1–100 characters.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final current = prefs.getStringList('waffra_custom_goals_v1') ??
          const <String>[];
      if (current.length > 1000 ||
          current.any((entry) => entry.trim().isEmpty ||
              entry.length > 512)) {
        throw StateError('Saved custom goal suggestions are invalid.');
      }
      final candidate = name.toLowerCase();
      if (current.any((existing) =>
          existing.trim().toLowerCase() == candidate)) {
        return false;
      }
      if (current.length >= 1000) {
        throw StateError('Custom goal suggestion capacity exceeded.');
      }
      final saved = await prefs.setStringList(
        'waffra_custom_goals_v1', [...current, name],
      );
      if (!saved) {
        throw StateError('Custom saving-goal suggestion could not be saved.');
      }
      return true;
    });
  }


  /// The Home and Android quick-add widget share this lock and crash journal.
  /// This bridge remains on guarded legacy storage; it never activates SQLCipher.
  Future<WaffraConfirmedLegacySmsResult> commitConfirmedLegacySms({
    required List<Map<String, Object?>> records,
    required List<String> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
  }) async {
    if (!userConfirmed) {
      throw StateError('Bank transaction batch was not confirmed.');
    }
    if (records.isEmpty || records.length > 100 ||
        messageHashes.length != records.length) {
      throw ArgumentError('Confirmed SMS batch must contain 1–100 records.');
    }
    final copied = <Map<String, Object?>>[];
    for (final record in records) {
      copied.add(Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(record)) as Map<String, dynamic>,
        ),
      ));
    }
    final hashes = List<String>.unmodifiable(messageHashes);
    const alphabet = '0123456789abcdef';
    for (final hash in hashes) {
      if (hash.length != 64 ||
          hash.split('').any((digit) => !alphabet.contains(digit))) {
        throw ArgumentError('Invalid SMS SHA-256 fingerprint.');
      }
    }
    if (!WaffraLegacyPreflight.inspect({
      'entries': jsonEncode(copied),
    }).canStage) {
      throw StateError('Confirmed SMS financial records are invalid.');
    }

    return coordinator.withCurrentPreferences((prefs) async {
      final previous = prefs.getString('entries') ?? '[]';
      final decoded = jsonDecode(previous);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw StateError('Persisted finance ledger has invalid encoding.');
      }
      final oldEntries = decoded
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final existingIds = oldEntries.map((item) => item['id']).toSet();
      final existingHashes = (prefs.getStringList('waffra_sms_hashes_v1') ??
          const <String>[]).toSet();
      final confirmed = <Map<String, Object?>>[];
      final newHashes = <String>{};
      var income = 0, expense = 0, incomeMinor = 0, expenseMinor = 0;
      var skipped = 0;
      for (var i = 0; i < copied.length; i++) {
        final item = copied[i];
        final hash = hashes[i];
        if (!allowDuplicateHashes &&
            (existingHashes.contains(hash) || newHashes.contains(hash))) {
          skipped++;
          continue;
        }
        if (!existingIds.add(item['id'])) {
          throw StateError('Duplicate transaction ID in confirmed batch.');
        }
        final amount = item['amount'];
        if (amount is! num || !amount.toDouble().isFinite || amount <= 0 ||
            ((amount * 100) - (amount * 100).round()).abs() > 1e-7) {
          throw StateError('Invalid transaction precision.');
        }
        confirmed.add(item);
        newHashes.add(hash);
        if (item['income'] == true) {
          income++;
          incomeMinor += (amount * 100).round();
        } else {
          expense++;
          expenseMinor += (amount * 100).round();
        }
      }
      if (confirmed.isNotEmpty) {
        final finalEntries = jsonEncode([...confirmed, ...oldEntries]);
        final finalHashes = {...existingHashes, ...newHashes}.toList()..sort();
        const journal = WaffraLegacyWidgetCommitJournal();
        await journal.prepare(
          prefs: prefs,
          nextEntries: finalEntries,
          nextHashes: finalHashes,
          nextRevision: DateTime.now().toUtc().toIso8601String(),
        );
        await journal.recover(prefs);
      }
      return WaffraConfirmedLegacySmsResult(
        savedEntriesRaw: prefs.getString('entries') ?? previous,
        savedHashes: List<String>.unmodifiable(
          prefs.getStringList('waffra_sms_hashes_v1') ?? const <String>[],
        ),
        widgetRevision: prefs.getString('waffra_widget_last_save_v1'),
        added: confirmed.length,
        savedIncome: income,
        savedExpenses: expense,
        incomeMinor: incomeMinor,
        expenseMinor: expenseMinor,
        skippedDuplicates: skipped,
      );
    });
  }

  /// Persist the screen's already-captured batch without mixing in profile
  /// settings. The cross-engine lock checks the exact ledger and widget
  /// revision before ANY field is changed. Returns the committed ledger
  /// witness for the next queued HomeScreen write.
  ///
  /// Journaled recovery completes a partially persisted legacy batch after
  /// process death; SQLCipher source activation is NOT implemented.
  Future<String> saveLegacy({
    required Map<String, Object> snapshot,
    required String? expectedLedgerRaw,
    required String? expectedWidgetRevision,
  }) async {
    // Defensively copy SMS hash lists before any asynchronous work. The
    // encrypted/legacy writer must persist exactly the user-confirmed batch.
    final captured = Map<String, Object>.unmodifiable(snapshot.map(
      (key, value) => MapEntry(
        key, value is List<String> ? List<String>.unmodifiable(value) : value,
      ),
    ));
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
      if (value is! String && value is! double && value is! bool &&
          !(WaffraLegacyPreflight.financeListOfStringsKeys
              .contains(entry.key) && value is List<String>)) {
        throw ArgumentError('Unsupported legacy financial value: ${entry.key}');
      }
    }
    await coordinator.withCurrentPreferences((preferences) async {
      WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
        preferences,
        expectedRaw: expectedLedgerRaw,
        expectedWidgetRevision: expectedWidgetRevision,
      );
      const batch = WaffraLegacyFinanceBatchJournal();
      await batch.prepare(prefs: preferences, nextValues: captured);
      await batch.recover(preferences);
    });
    return entries;
  }
}

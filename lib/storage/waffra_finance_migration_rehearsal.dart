import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';

/// Results are evidence for a DRY RUN, never permission to switch data source.
class WaffraFinanceMigrationRehearsalResult {
  const WaffraFinanceMigrationRehearsalResult({
    required this.legacyDigest,
    required this.encryptedDigest,
    required this.itemCounts,
    required this.legacyReceiptReferences,
    required this.stagedGeneration,
  });

  final String legacyDigest;
  final String encryptedDigest;
  final Map<String, int> itemCounts;
  final int legacyReceiptReferences;
  final int stagedGeneration;

  bool get needsReceiptMigration => legacyReceiptReferences > 0;
}

/// Carefully copies EVERY recognized finance key from the live legacy source
/// to an isolated, already opened TEST SQLCipher vault without changing the
/// active finance source or setting activation markers.
///
/// Production Waffra does NOT invoke this automatically. An eventual source
/// switch additionally needs complete receipt-copy verification, a durable
/// two-witness activation, secure key handling and ALL app/widget writers
/// routed to the encrypted finance snapshot.
class WaffraFinanceMigrationRehearsal {
  const WaffraFinanceMigrationRehearsal({
    required this.encrypted,
    required this.coordinator,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot encrypted;
  final WaffraLegacyFinanceWriterCoordinator coordinator;
  final bool experimentalEnabled;

  static Map<String, Object?> _capture(SharedPreferences prefs) {
    final result = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys) {
      if (!prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      if (value is List<String>) {
        result[key] = List<String>.unmodifiable(value);
      } else if (value is String || value is bool || value is num) {
        result[key] = value;
      } else {
        throw StateError('Unexpected existing finance type for $key.');
      }
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  static int _receiptReferences(Map<String, Object?> finance) {
    final raw = finance['entries'];
    if (raw == null) return 0;
    final entries = jsonDecode(raw as String) as List<dynamic>;
    var count = 0;
    for (final element in entries) {
      final row = element as Map;
      final path = row['receiptPath'];
      if (path == null || path == '') continue;
      if (path is! String) {
        throw StateError('Unexpected legacy receipt path type.');
      }
      if (path.startsWith('[')) {
        final paths = jsonDecode(path) as List<dynamic>;
        count += paths.length;
      } else {
        count++;
      }
    }
    return count;
  }

  Future<WaffraFinanceMigrationRehearsalResult> run() async {
    if (!experimentalEnabled) {
      throw StateError('Finance migration dress rehearsal is disabled.');
    }
    // The coordinator reloads prefs and recovers an unfinished widget journal
    // while holding the SAME app/widget finance writer lock.
    return coordinator.withCurrentPreferences((prefs) async {
      final original = _capture(prefs);
      final report = WaffraLegacyPreflight.inspect(original);
      if (!report.canStage) {
        throw StateError('Legacy finance failed preflight, no copy attempted.');
      }

      // A prior rehearsal/activation must NEVER be overwritten. The caller
      // supplies a NEW, isolated encrypted test vault, not the live database.
      final zero = await encrypted.initializeEmpty();
      if (zero.generation != 0 || zero.values.isNotEmpty) {
        throw StateError('Test vault already contains finance; refusing reset.');
      }
      final committed = await encrypted.commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: original,
      );
      final reread = await encrypted.read();
      if (reread.generation != 1 ||
          committed.digest != reread.digest ||
          jsonEncode(original) != jsonEncode(reread.values)) {
        throw StateError('Encrypted finance copy failed byte/value parity.');
      }
      // Re-read native SharedPreferences under the writer lock, proving the
      // source has not moved or been reset during the encrypted staging.
      await prefs.reload();
      final after = _capture(prefs);
      final newReport = WaffraLegacyPreflight.inspect(after);
      if (!newReport.canStage ||
          newReport.sourceSha256 != report.sourceSha256 ||
          jsonEncode(after) != jsonEncode(original)) {
        throw StateError('Legacy data changed during rehearsal.');
      }

      return WaffraFinanceMigrationRehearsalResult(
        legacyDigest: report.sourceSha256,
        encryptedDigest: reread.digest,
        itemCounts: Map.unmodifiable(report.itemCounts),
        legacyReceiptReferences: _receiptReferences(original),
        stagedGeneration: reread.generation,
      );
    });
  }
}

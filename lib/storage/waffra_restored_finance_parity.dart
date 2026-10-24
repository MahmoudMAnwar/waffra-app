import 'dart:convert';

import 'legacy_snapshot_preflight.dart';

/// Read-only parity checks for a previously authenticated portable restore.
/// No SQLite writes, source switch, marker mutation or release authorization.
class WaffraRestoredFinanceParity {
  const WaffraRestoredFinanceParity._();

  /// The encrypted snapshot must contain exactly the authenticated finance
  /// keys. Custom goal suggestions use a separate typed SQL table.
  static void requireExactFinanceKeys({
    required Map<String, Object?> archive,
    required Map<String, Object?> restored,
  }) {
    final known = WaffraLegacyPreflight.allKeys.toSet();
    final unexpectedArchive = archive.keys.where((key) =>
        !known.contains(key) && key != 'waffra_custom_goals_v1');
    if (unexpectedArchive.isNotEmpty || restored.keys.any((key) =>
        !known.contains(key))) {
      throw StateError('Unexpected finance restore key.');
    }
    final expected = archive.keys.where(known.contains).toSet();
    final actual = restored.keys.toSet();
    if (expected.length != actual.length ||
        !expected.containsAll(actual) || !actual.containsAll(expected)) {
      throw StateError('Restored finance key set differs from archive.');
    }
  }

  /// Only receiptPath may change to a verified, device-independent BLOB
  /// reference. An injected or missing transaction field is not acceptable.
  static void requireExactTransactionFields({
    required Map<String, dynamic> original,
    required Map<String, dynamic> restored,
  }) {
    final oldKeys = original.keys.where((key) => key != 'receiptPath').toSet();
    final newKeys = restored.keys.where((key) => key != 'receiptPath').toSet();
    if (oldKeys.length != newKeys.length ||
        !oldKeys.containsAll(newKeys) || !newKeys.containsAll(oldKeys)) {
      throw StateError('Restored transaction fields differ from archive.');
    }
    for (final key in oldKeys) {
      if (jsonEncode(original[key]) != jsonEncode(restored[key])) {
        throw StateError('Restored transaction contents changed.');
      }
    }
  }
}

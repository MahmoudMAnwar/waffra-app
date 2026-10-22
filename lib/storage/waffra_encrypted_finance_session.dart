import 'dart:convert';
import 'dart:typed_data';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_unified_finance_writer.dart';
import 'waffra_verified_encrypted_finance_bridge.dart';

/// One typed finance entry point for dashboard, category/goal/recurring
/// editors, bank SMS and Android widget ONCE production selects a verified
/// encrypted source. No caller is allowed to fall back to SharedPreferences.
///
/// Deliberately not installed in main.dart or the widget until cutover
/// coordination, key recovery and receipt upload are fully verified.
class WaffraEncryptedFinanceSession {
  const WaffraEncryptedFinanceSession({
    required this.bridge,
    this.experimentalEnabled = false,
  });

  final WaffraVerifiedEncryptedFinanceBridge bridge;
  final bool experimentalEnabled;

  void _requireEnabled() {
    if (!experimentalEnabled) {
      throw StateError('Encrypted finance source has not been selected.');
    }
  }

  /// The widget revision is the actual monotonic SQLCipher generation.
  Future<WaffraEncryptedHomeWitness> loadForDashboardOrWidget() async {
    _requireEnabled();
    final witness = await bridge.loadForHomeAndWidget();
    witness.finance.requireIntegrity();
    return witness;
  }

  /// Atomically apply explicitly changed category, goal, recurring, budget,
  /// deletion, SMS-hash or transaction fields. An unrelated widget write may
  /// proceed, but a simultaneous edit of the same field is a hard conflict.
  Future<WaffraFinanceSnapshotState> saveChangedFields({
    required WaffraEncryptedHomeWitness baseline,
    required Map<String, Object?> changedValues,
  }) async {
    _requireEnabled();
    if (changedValues.isEmpty ||
        changedValues.keys.any(
          (key) => !WaffraLegacyPreflight.allKeys.contains(key))) {
      throw ArgumentError('Only recognized finance fields may be edited.');
    }
    return bridge.saveHomeChanges(
      baseline: baseline,
      replacements: Map<String, Object?>.unmodifiable(changedValues),
      changedKeys: changedValues.keys.toSet(),
    );
  }

  /// Converts the HomeScreen's full captured batch into a delta against the
  /// exact view originally loaded, so widget SMS changes are never silently
  /// overwritten by stale dashboard fields. Missing keys remain missing.
  Future<WaffraFinanceSnapshotState> saveDashboardBatch({
    required WaffraEncryptedHomeWitness baseline,
    required Map<String, Object> captured,
  }) async {
    _requireEnabled();
    final known = WaffraLegacyPreflight.allKeys.toSet();
    if (captured.isEmpty ||
        captured.keys.any((key) => !known.contains(key))) {
      throw ArgumentError('Invalid captured financial dashboard batch.');
    }
    final delta = <String, Object?>{};
    for (final item in captured.entries) {
      final old = baseline.snapshot.values[item.key];
      if (!baseline.snapshot.values.containsKey(item.key) ||
          jsonEncode(old) != jsonEncode(item.value)) {
        delta[item.key] = item.value;
      }
    }
    if (delta.isEmpty) {
      // Never accept a stale no-op as proof of the current balance.
      final latest = await loadForDashboardOrWidget();
      return latest.snapshot;
    }
    return saveChangedFields(baseline: baseline, changedValues: delta);
  }

  /// Persist deduplication hashes without replacing hashes just added by
  /// a separate widget engine. Never store raw bank SMS or bank credentials.
  Future<WaffraFinanceSnapshotState> addSmsHashes(
    Iterable<String> hashes,
  ) async {
    _requireEnabled();
    return bridge.mergeConfirmedSmsHashes(hashes.toList(growable: false));
  }

  /// Save explicitly confirmed manual/SMS transactions under the same
  /// SQLCipher source lock used by dashboard edits and the widget.
  Future<WaffraUnifiedWriteResult> appendConfirmed({
    required List<Map<String, Object?>> records,
    required List<String?> hashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
  }) async {
    _requireEnabled();
    return bridge.appendConfirmedTransactions(
      records: records,
      messageHashes: hashes,
      userConfirmed: userConfirmed,
      allowDuplicateHashes: allowDuplicateHashes,
    );
  }

  Future<List<Uint8List>> readReceiptImages(String entryId) async {
    _requireEnabled();
    return bridge.loadReceiptImages(entryId: entryId);
  }

  Future<WaffraFinanceReadView> readValidatedFinance() async =>
      (await loadForDashboardOrWidget()).finance;
}

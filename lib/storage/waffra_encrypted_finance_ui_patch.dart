import 'dart:convert';
import 'dart:io';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_experimental_writer_gate.dart';

/// A finance screen must keep the exact *baseline values* it loaded.
/// A UI save only patches changed finance fields instead of blindly
/// overwriting every key with its stale in-memory view.
///
/// The Android widget can append a transaction in between loading a goal
/// screen and saving that goal. Unrelated entry changes are preserved, but
/// conflicting updates to the SAME field fail rather than silently win.
class WaffraEncryptedFinanceUiPatch {
  const WaffraEncryptedFinanceUiPatch({
    required this.snapshot,
    required this.writerDirectory,
    this.experimentalEnabled = false,
    this.verifySourceUnderLock,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final bool experimentalEnabled;

  /// Runtime selector witness. Must run under the app/widget native lock.
  /// A disposable test writer may omit this, but an activated app must not.
  final Future<void> Function()? verifySourceUnderLock;

  Future<WaffraFinanceSnapshotState> readForScreen() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted UI finance patching is disabled.');
    }
    return snapshot.read();
  }

  /// Saves only keys named in [changedKeys]. Values and keys not mentioned
  /// are retained exactly, even if another writer changed them.
  ///
  /// [screenBaseline] MUST come from the preceding readForScreen() result.
  /// A conflict on a changed key blocks the entire batch; caller must reload.
  Future<WaffraFinanceSnapshotState> saveScreenChanges({
    required Map<String, Object?> screenBaseline,
    required Map<String, Object?> replacementValues,
    required Set<String> changedKeys,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted UI finance patching is disabled.');
    }
    final known = WaffraLegacyPreflight.allKeys.toSet();
    if (changedKeys.isEmpty ||
        changedKeys.any((key) => !known.contains(key))) {
      throw ArgumentError('Invalid or missing finance fields to save.');
    }
    for (final key in changedKeys) {
      if (!replacementValues.containsKey(key) ||
          replacementValues[key] == null) {
        throw ArgumentError('Cannot silently clear a finance field.');
      }
    }

    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock?.call();
      final latest = await snapshot.read();
      for (final key in changedKeys) {
        final beforeExists = screenBaseline.containsKey(key);
        final nowExists = latest.values.containsKey(key);
        // Compare the exact JSON-compatible scalar/list value, including
        // absent-vs-empty distinction, before applying this field's edit.
        if (beforeExists != nowExists ||
            (beforeExists &&
                jsonEncode(screenBaseline[key]) !=
                    jsonEncode(latest.values[key]))) {
          throw StateError('Finance screen has stale $key; reload first.');
        }
      }
      final merged = Map<String, Object?>.from(latest.values);
      for (final key in changedKeys) {
        merged[key] = replacementValues[key];
      }
      return snapshot.commit(
        expectedGeneration: latest.generation,
        fullFinanceSnapshot: merged,
      );
    });
  }
}

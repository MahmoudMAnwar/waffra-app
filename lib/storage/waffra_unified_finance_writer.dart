import 'dart:convert';
import 'dart:io';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_experimental_writer_gate.dart';

class WaffraUnifiedWriteResult {
  const WaffraUnifiedWriteResult({
    required this.saved,
    required this.savedIncome,
    required this.savedExpenses,
    required this.skippedDuplicates,
    required this.generation,
  });

  final int saved;
  final int savedIncome;
  final int savedExpenses;
  final int skippedDuplicates;
  final int generation;
}

/// A single lossless finance writer to be shared by the dashboard and widget
/// only after both have been moved to the same encrypted data source.
///
/// Current production UI and quick-add widget are NOT yet wired to this.
/// This isolated rehearsal never touches SharedPreferences or real receipts.
class WaffraUnifiedFinanceWriter {
  const WaffraUnifiedFinanceWriter({
    required this.writerDirectory,
    required this.snapshot,
    this.experimentalEnabled = false,
    this.verifySourceUnderLock,
  });

  final Directory writerDirectory;
  final WaffraAtomicFinanceSnapshot snapshot;
  final bool experimentalEnabled;

  /// Optional runtime source verification. Executed while holding the same
  /// app/widget native lock, before reading or changing finance. Never use
  /// an unchecked writer in an activated installation.
  final Future<void> Function()? verifySourceUnderLock;

  /// Called AFTER explicit confirmation for bank SMS, or on a manual save.
  /// Hashes align one-to-one with entries, and may be null for manual entries.
  /// The only finance fields this operation changes are entries and SMS hashes.
  ///
  /// Every caller takes the SAME lock, re-reads latest state INSIDE it, and
  /// commits with the source revision to avoid widget/dashboard lost updates.
  Future<WaffraUnifiedWriteResult> appendTransactions({
    required List<Map<String, Object?>> records,
    required List<String?> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Unified finance writer is disabled by default.');
    }
    if (!userConfirmed) {
      throw StateError('Explicit finance save confirmation was not granted.');
    }
    if (records.isEmpty || records.length > 100 ||
        messageHashes.length != records.length) {
      throw ArgumentError('A save requires 1 to 100 aligned transactions.');
    }
    for (var index = 0; index < records.length; index++) {
      final data = records[index];
      final hash = messageHashes[index];
      if (hash != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError('Invalid SMS digest.');
      }
      if (data['receiptPath'] != null && data['receiptPath'] != '') {
        throw StateError('Receipts require their own verified file installer.');
      }
      // Delegate financial value, ID, date and amount validation to the same
      // existing migration preflight instead of silently coercing money.
      final check = WaffraLegacyPreflight.inspect({
        'entries': jsonEncode([data]),
      });
      if (!check.canStage) {
        throw ArgumentError('Invalid transaction data.');
      }
      if (data['id'] is! String || (data['id'] as String).trim().isEmpty ||
          data['title'] is! String ||
          (data['title'] as String).trim().isEmpty ||
          data['category'] is! String ||
          (data['category'] as String).trim().isEmpty) {
        throw ArgumentError('Transaction ID, title and category are required.');
      }
    }

    final gate = WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    );
    return gate.withExclusiveAccess(() async {
      await verifySourceUnderLock?.call();
      final current = await snapshot.read();
      final next = Map<String, Object?>.from(current.values);
      final decoded = jsonDecode((next['entries'] as String?) ?? '[]');
      if (decoded is! List) {
        throw StateError('Existing finance entries have invalid storage.');
      }
      final list = decoded.map<Map<String, Object?>>((item) {
        if (item is! Map) throw StateError('Invalid saved finance entry.');
        return Map<String, Object?>.from(item);
      }).toList();
      final ids = list.map((item) => item['id']).toSet();
      final existingHashes = Set<String>.from(
        next['waffra_sms_hashes_v1'] as List<String>? ?? const <String>[],
      );
      var savedIncome = 0, savedExpenses = 0, skipped = 0;
      for (var i = 0; i < records.length; i++) {
        final record = Map<String, Object?>.from(records[i]);
        final hash = messageHashes[i];
        if (hash != null && !allowDuplicateHashes &&
            existingHashes.contains(hash)) {
          skipped++;
          continue;
        }
        if (!ids.add(record['id'])) {
          throw StateError('Duplicate transaction ID; refusing partial save.');
        }
        list.add(record);
        if (hash != null) existingHashes.add(hash);
        if (record['income'] == true) {
          savedIncome++;
        } else {
          savedExpenses++;
        }
      }
      final saved = savedIncome + savedExpenses;
      if (saved == 0) {
        return WaffraUnifiedWriteResult(
          saved: 0, savedIncome: 0, savedExpenses: 0,
          skippedDuplicates: skipped, generation: current.generation,
        );
      }
      // No changes to goals, deleted records, categories, recurring budgets or
      // settings. Unlike the existing widget's prefs.setString, this mutation
      // applies to CURRENT persisted finance state, not stale screen state.
      next['entries'] = jsonEncode(list);
      if (messageHashes.any((hash) => hash != null)) {
        next['waffra_sms_hashes_v1'] = existingHashes.toList()..sort();
      }
      final written = await snapshot.commit(
        expectedGeneration: current.generation,
        fullFinanceSnapshot: next,
      );
      return WaffraUnifiedWriteResult(
        saved: saved,
        savedIncome: savedIncome,
        savedExpenses: savedExpenses,
        skippedDuplicates: skipped,
        generation: written.generation,
      );
    });
  }
}

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
    this.incomeMinor = 0,
    this.expenseMinor = 0,
    required this.skippedDuplicates,
    required this.generation,
  });

  final int saved;
  final int savedIncome;
  final int savedExpenses;
  final int incomeMinor, expenseMinor;
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
    // Freeze the entire confirmed payload BEFORE awaiting the shared native
    // lock or source witness. The caller (Home form, SMS parser or widget)
    // can reuse and mutate both lists and their maps while this runs.
    // A JSON round-trip also isolates nested JSON data from caller memory.
    final confirmedRecords = <Map<String, Object?>>[];
    for (final record in records) {
      final decoded = jsonDecode(jsonEncode(record));
      if (decoded is! Map<String, dynamic>) {
        throw ArgumentError('Invalid confirmed transaction payload.');
      }
      confirmedRecords.add(Map<String, Object?>.unmodifiable(decoded));
    }
    final confirmedHashes = List<String?>.unmodifiable(messageHashes);
    for (var index = 0; index < confirmedRecords.length; index++) {
      final data = confirmedRecords[index];
      final hash = confirmedHashes[index];
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
      return snapshot.store.transaction(() async {
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
        // M76 writes normalized SQL and the canonical finance snapshot in
        // one transaction. The unified Home/widget writer must do the same.
        // A count-only check can miss equal-sized, mismatched ID sets.
        final sqlRows = await snapshot.store.customSelect(
          'SELECT entry_id FROM fresh_finance_entries',
        ).get();
        final normalizedIds = sqlRows
            .map((row) => row.read<String>('entry_id')).toSet();
        if (sqlRows.length != list.length ||
            normalizedIds.length != list.length ||
            !normalizedIds.containsAll(ids) ||
            !ids.containsAll(normalizedIds)) {
          throw StateError('Encrypted SQL ledger differs from screen snapshot.');
        }
        final existingHashes = Set<String>.from(
          next['waffra_sms_hashes_v1'] as List<String>? ?? const <String>[],
        );
        var savedIncome = 0, savedExpenses = 0, skipped = 0;
        var incomeMinor = 0, expenseMinor = 0;
        for (var i = 0; i < confirmedRecords.length; i++) {
          final record = confirmedRecords[i];
          final hash = confirmedHashes[i];
          if (hash != null && !allowDuplicateHashes &&
              existingHashes.contains(hash)) {
            skipped++;
            continue;
          }
          if (!ids.add(record['id'])) {
            throw StateError('Duplicate transaction ID; refusing partial save.');
          }
          // Save both projections under the SAME SQLCipher transaction; if
          // any row insert or snapshot commit fails, no finance or hash is
          // persisted. Receipt-bearing records are rejected above.
          await snapshot.store.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES(?,?,?,?,?,?,?,?)',
            [
              record['id'], record['title'], record['category'],
              ((record['amount'] as num) * 100).round(),
              record['income'] == true ? 1 : 0,
              record['date'], 0, jsonEncode(record),
            ],
          );
          list.add(record);
          if (hash != null) existingHashes.add(hash);
          final minor = ((record['amount'] as num) * 100).round();
          if (record['income'] == true) {
            savedIncome++;
            incomeMinor += minor;
          } else {
            savedExpenses++;
            expenseMinor += minor;
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
        if (confirmedHashes.any((hash) => hash != null)) {
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
          incomeMinor: incomeMinor,
          expenseMinor: expenseMinor,
          skippedDuplicates: skipped,
          generation: written.generation,
        );
      });
    });
  }
}

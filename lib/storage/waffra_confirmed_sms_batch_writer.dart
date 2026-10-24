import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

/// Normalized user-approved financial transaction, NOT a raw bank SMS.
/// Only a one-way message hash should be persisted for deduplication.
/// The screen must avoid including account identifiers in displayTitle.
class WaffraConfirmedSmsEntry {
  const WaffraConfirmedSmsEntry({
    required this.id,
    required this.messageHash,
    required this.displayTitle,
    required this.category,
    required this.amountMinor,
    required this.isIncome,
    required this.occurredIso,
  });

  final String id;
  final String messageHash;
  final String displayTitle;
  final String category;
  final int amountMinor;
  final bool isIncome;
  final String occurredIso;
}

class WaffraSmsPersistenceResult {
  const WaffraSmsPersistenceResult({
    required this.detected,
    required this.saved,
    required this.savedIncome,
    required this.savedExpenses,
    required this.skippedDuplicates,
    required this.incomeMinor,
    required this.expensesMinor,
  });

  final int detected;
  final int saved;
  final int savedIncome;
  final int savedExpenses;
  final int skippedDuplicates;
  final int incomeMinor;
  final int expensesMinor;
}

/// Persists a confirmed batch (maximum 100) and its deduplication hashes
/// in ONE encrypted SQLite transaction. No raw SMS is retained here.
///
/// This is a test-only building block. Existing main.dart and Android widget
/// continue using SharedPreferences until a crash-safe single-writer switch.
class WaffraConfirmedSmsBatchWriter {
  const WaffraConfirmedSmsBatchWriter({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static void _validate(WaffraConfirmedSmsEntry item) {
    if (item.id.trim().isEmpty || item.id.length > 256 ||
        item.displayTitle.trim().isEmpty ||
        item.category.trim().isEmpty ||
        item.amountMinor <= 0 ||
        item.amountMinor > 9007199254740991 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(item.messageHash) ||
        DateTime.tryParse(item.occurredIso) == null) {
      throw ArgumentError('Invalid normalized SMS finance transaction.');
    }
  }

  Future<WaffraSmsPersistenceResult> saveConfirmed({
    required bool userConfirmed,
    required List<WaffraConfirmedSmsEntry> records,
    bool allowDuplicates = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted bank SMS import is disabled by default.');
    }
    if (!userConfirmed) {
      throw StateError('Explicit user confirmation is required before saving.');
    }
    if (records.length > 100) {
      throw ArgumentError('Maximum 100 SMS transactions per confirmed batch.');
    }
    for (final item in records) {
      _validate(item);
    }

    return store.transaction(() async {
      final meta = await store.customSelect(
        "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
      ).get();
      if (meta.length != 1 ||
          meta.single.read<int>('schema_version') !=
              WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
        throw StateError('Encrypted financial storage not initialized.');
      }
      final shadow = await store.customSelect(
        'SELECT count(*) AS n FROM shadow_vaults',
      ).getSingle();
      if (shadow.read<int>('n') != 0) {
        throw StateError('Cannot import SMS in a legacy migration sandbox.');
      }
      final before = await store.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_entries',
      ).getSingle();

      var savedIncome = 0;
      var savedExpenses = 0;
      var skippedDuplicates = 0;
      var incomeMinor = 0;
      var expensesMinor = 0;
      final seen = <String>{};

      for (final item in records) {
        final duplicateInsideBatch = !seen.add(item.messageHash);
        final known = await store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes '
          'WHERE message_hash = ?',
          variables: [Variable.withString(item.messageHash)],
        ).get();
        if (!allowDuplicates && (duplicateInsideBatch || known.isNotEmpty)) {
          skippedDuplicates++;
          continue;
        }
        final financeJson = jsonEncode({
          'id': item.id,
          'title': item.displayTitle,
          'category': item.category,
          'amount': item.amountMinor / 100,
          'income': item.isIncome,
          'date': item.occurredIso,
          'receiptPath': null,
        });
        await store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
          [
            item.id,
            item.displayTitle,
            item.category,
            item.amountMinor,
            item.isIncome ? 1 : 0,
            item.occurredIso,
            0,
            financeJson,
          ],
        );
        if (known.isEmpty) {
          await store.customStatement(
            'INSERT INTO fresh_finance_sms_hashes(message_hash) VALUES (?)',
            [item.messageHash],
          );
        }
        if (item.isIncome) {
          savedIncome++;
          incomeMinor += item.amountMinor;
        } else {
          savedExpenses++;
          expensesMinor += item.amountMinor;
        }
      }
      final after = await store.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_entries',
      ).getSingle();
      final confirmedSaves = savedIncome + savedExpenses;
      if (after.read<int>('n') - before.read<int>('n') != confirmedSaves ||
          confirmedSaves + skippedDuplicates != records.length) {
        throw StateError('Persisted SMS records failed SQLite parity.');
      }
      return WaffraSmsPersistenceResult(
        detected: records.length,
        saved: confirmedSaves,
        savedIncome: savedIncome,
        savedExpenses: savedExpenses,
        skippedDuplicates: skippedDuplicates,
        incomeMinor: incomeMinor,
        expensesMinor: expensesMinor,
      );
    });
  }
}

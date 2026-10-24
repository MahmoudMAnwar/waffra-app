import 'dart:convert';

import 'waffra_encrypted_store.dart';

/// Ensures a screen-side edit of an EXISTING transaction also updates the
/// canonical relational SQLCipher ledger in the SAME transaction as its
/// finance snapshot. An insert belongs to WaffraUnifiedFinanceWriter; deletes
/// need a separate receipt+SMS-hash retention contract and fail closed here.
///
/// The caller must hold the common app/widget writer lock, its source witness,
/// and the SQL transaction enclosing the snapshot commit. Never call alone.
class WaffraEncryptedEntryProjectionGuard {
  const WaffraEncryptedEntryProjectionGuard._();

  static Map<String, Map<String, dynamic>> _decode(String? raw) {
    final data = jsonDecode(raw ?? '[]');
    if (data is! List) {
      throw StateError('Encrypted transaction list is malformed.');
    }
    final rows = <String, Map<String, dynamic>>{};
    for (final item in data) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).trim().isEmpty ||
          rows.containsKey(item['id'])) {
        throw StateError('Encrypted transaction identity is ambiguous.');
      }
      rows[item['id'] as String] = item;
    }
    return rows;
  }

  static int _minor(Object? value) {
    if (value is! num || !value.toDouble().isFinite ||
        value < 0 || (value * 100 - (value * 100).round()).abs() > 1e-7) {
      throw StateError('Updated transaction has invalid halala precision.');
    }
    return (value * 100).round();
  }

  static Future<void> reconcile({
    required WaffraEncryptedStore store,
    required String? previousJson,
    required String? updatedJson,
  }) async {
    final before = _decode(previousJson);
    final after = _decode(updatedJson);

    // This screen patch only edits existing IDs. For adds use the atomic
    // confirmed writer; for deletes coordinate receipt blobs and dedupe IDs.
    if (before.length != after.length ||
        !before.keys.toSet().containsAll(after.keys)) {
      throw StateError(
        'Transaction add/delete needs its dedicated atomic encrypted writer.',
      );
    }

    final sql = await store.customSelect(
      'SELECT entry_id,source_json,receipt_count FROM fresh_finance_entries',
    ).get();
    if (sql.length != before.length) {
      throw StateError('SQLCipher transaction projection differs from UI.');
    }
    final relational = <String, dynamic>{};
    for (final row in sql) {
      final id = row.read<String>('entry_id');
      if (relational.containsKey(id) || !before.containsKey(id) ||
          jsonEncode(jsonDecode(row.read<String>('source_json'))) !=
              jsonEncode(before[id])) {
        throw StateError('SQLCipher transaction projection is inconsistent.');
      }
      relational[id] = row;
    }
    for (final next in after.entries) {
      final id = next.key;
      final original = before[id]!;
      final changed = next.value;
      if (jsonEncode(original) == jsonEncode(changed)) continue;
      if (changed['id'] != id ||
          changed['title'] is! String ||
          (changed['title'] as String).trim().isEmpty ||
          changed['category'] is! String ||
          (changed['category'] as String).trim().isEmpty ||
          changed['income'] is! bool ||
          changed['date'] is! String ||
          DateTime.tryParse(changed['date'] as String) == null ||
          changed['receiptPath'] != original['receiptPath']) {
        throw StateError('Unsafe transaction/receipt update was rejected.');
      }
      final minor = _minor(changed['amount']);
      await store.customStatement(
        'UPDATE fresh_finance_entries SET '
        'title=?,category_snapshot=?,amount_minor=?,is_income=?,'
        'occurred_iso=?,source_json=? WHERE entry_id=?',
        [
          changed['title'],
          changed['category'],
          minor,
          changed['income'] == true ? 1 : 0,
          changed['date'],
          jsonEncode(changed),
          id,
        ],
      );
    }
  }
}

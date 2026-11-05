import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// SQL-only parents precede dependent rows. Ledger entries are restored by V2.
abstract final class WaffraAccountsFinanceHistory {
  static const tables = [
    'fresh_finance_categories',
    'fresh_finance_goals',
    'fresh_finance_recurring',
    ...WaffraFreshFinanceDomainSchema.domainTables,
  ];
  static const entryCategories = 'entryCategoryLinks';
  static const maxRows = 100000;

  static Future<Map<String, Object?>> capture(WaffraEncryptedStore store) async {
    final records = <String, Object?>{};
    var remaining = maxRows;
    for (final table in tables) {
      final rows = await store.customSelect(
        'SELECT * FROM $table ORDER BY rowid LIMIT ${remaining + 1}',
      ).get();
      if (rows.length > remaining) {
        throw StateError('Finance history exceeds archive capacity.');
      }
      remaining -= rows.length;
      records[table] = rows.map((row) => row.data).toList(growable: false);
    }
    final links = await store.customSelect(
      'SELECT entry_id,category_id FROM fresh_finance_entries '
      'WHERE category_id IS NOT NULL ORDER BY entry_id LIMIT ${remaining + 1}',
    ).get();
    if (links.length > remaining) {
      throw StateError('Entry category links exceed archive capacity.');
    }
    records[entryCategories] = links.map((row) => row.data).toList(growable: false);
    if ((await store.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw StateError('Finance history contains broken links.');
    }
    return records;
  }

  static Map<String, dynamic> validate(Object? raw) {
    if (raw is! Map<String, dynamic> || raw.length != tables.length + 1) {
      throw const FormatException('Invalid finance history tables.');
    }
    var total = 0;
    for (final table in [...tables, entryCategories]) {
      final rows = raw[table];
      if (rows is! List || (total += rows.length) > maxRows ||
          rows.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException('Invalid finance history rows.');
      }
    }
    return raw;
  }

  static Future<void> restore(
    WaffraEncryptedStore store, Map<String, dynamic> records,
  ) async {
    await WaffraFreshFinanceDomainSchema.requireReady(store);
    for (final table in tables) {
      if ((await store.customSelect('SELECT 1 FROM $table LIMIT 1').get()).isNotEmpty) {
        throw StateError('Target finance history is not empty.');
      }
      // Identifiers come exclusively from the local versioned schema.
      final schema = await store.customSelect('PRAGMA table_info($table)').get();
      final columns = schema.map((c) => c.read<String>('name')).toList();
      final placeholders = List.filled(columns.length, '?').join(',');
      final recorded = (records[table] as List).cast<Map<String, dynamic>>();
      final ordered = table == 'fresh_finance_categories'
          ? (List<Map<String, dynamic>>.of(recorded)..sort((a, b) {
              // A restored subcategory must never precede its parent when
              // new SQLCipher parent-consistency triggers are installed.
              final aChild = (a['parent_id'] as String? ?? '').isNotEmpty;
              final bChild = (b['parent_id'] as String? ?? '').isNotEmpty;
              return (aChild ? 1 : 0).compareTo(bChild ? 1 : 0);
            }))
          : recorded;
      for (final row in ordered) {
        if (row.length != columns.length || !columns.every(row.containsKey)) {
          throw const FormatException('Invalid finance history columns.');
        }
        for (final column in schema) {
          final value = row[column.read<String>('name')];
          final integer = column.read<String>('type') == 'INTEGER';
          if (value == null ? column.read<int>('notnull') != 0 :
              (integer ? value is! int : value is! String)) {
            throw const FormatException('Invalid finance history field type.');
          }
        }
        await store.customStatement(
          'INSERT INTO $table (${columns.join(',')}) VALUES ($placeholders)',
          [for (final column in columns) row[column]],
        );
      }
    }
    for (final link in (records[entryCategories] as List).cast<Map<String, dynamic>>()) {
      if (link.length != 2 || link['entry_id'] is! String || link['category_id'] is! String) {
        throw const FormatException('Malformed entry category link.');
      }
      await store.customStatement(
        'UPDATE fresh_finance_entries SET category_id=? WHERE entry_id=? AND category_id IS NULL',
        [link['category_id'], link['entry_id']],
      );
      final changed = await store.customSelect('SELECT changes() AS n').getSingle();
      if (changed.read<int>('n') != 1) {
        throw const FormatException('Missing or duplicate entry category link.');
      }
    }
    if ((await store.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw const FormatException('Orphan finance history record.');
    }
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import 'legacy_financial_snapshot.dart';
import 'legacy_snapshot_preflight.dart' as strict;
import 'waffra_encrypted_store.dart';

/// Copy-on-write typed projection of the old Waffra JSON records.
///
/// This is a shadow import, not the app's active ledger. Financial screens
/// continue to use SharedPreferences until an explicit later cutover.
/// Every old raw record also remains in shadow_records for round-trip audits.
class WaffraNormalizedImporter {
  const WaffraNormalizedImporter(this.store);
  final WaffraEncryptedStore store;

  static const _ddl = <String>[
    '''
CREATE TABLE IF NOT EXISTS normalized_entries (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  entry_id TEXT NOT NULL,
  title TEXT NOT NULL,
  category_snapshot TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
  is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
  occurred_original_iso TEXT NOT NULL,
  occurred_local_date TEXT NOT NULL,
  receipt_raw TEXT,
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,entry_id)
)''',
    '''
CREATE INDEX IF NOT EXISTS idx_normalized_entries_date
ON normalized_entries(vault_id,occurred_local_date,entry_id)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_categories (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  category_id TEXT NOT NULL,
  name TEXT NOT NULL,
  parent_id TEXT NOT NULL,
  is_income INTEGER NOT NULL CHECK(is_income IN(0,1)),
  budget_minor INTEGER NOT NULL CHECK(budget_minor >= 0),
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,category_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_goals (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  goal_id TEXT NOT NULL,
  name TEXT NOT NULL,
  target_minor INTEGER NOT NULL CHECK(target_minor > 0),
  saved_minor INTEGER NOT NULL CHECK(saved_minor >= 0),
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,goal_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_recurring (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  recurring_id TEXT NOT NULL,
  title TEXT NOT NULL,
  category_snapshot TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
  is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
  due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
  is_active INTEGER NOT NULL CHECK(is_active IN (0,1)),
  start_original_iso TEXT NOT NULL,
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,recurring_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_challenges (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  challenge_id TEXT NOT NULL,
  title TEXT NOT NULL,
  daily_amount_minor INTEGER NOT NULL CHECK(daily_amount_minor >= 0),
  days INTEGER NOT NULL CHECK(days > 0),
  completed_days INTEGER NOT NULL CHECK(completed_days >= 0),
  last_done_iso TEXT,
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,challenge_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_receipts (
  vault_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  position INTEGER NOT NULL CHECK(position >= 0),
  local_file_path TEXT NOT NULL,
  PRIMARY KEY(vault_id,entry_id,position),
  FOREIGN KEY(vault_id,entry_id)
    REFERENCES normalized_entries(vault_id,entry_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_deleted (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  source_key TEXT NOT NULL,
  source_index INTEGER NOT NULL,
  entity_id TEXT NOT NULL,
  deleted_at_original_iso TEXT NOT NULL,
  original_json TEXT NOT NULL,
  PRIMARY KEY(vault_id,source_key,source_index)
)''',
    '''
CREATE TABLE IF NOT EXISTS normalized_imports (
  vault_id TEXT PRIMARY KEY REFERENCES shadow_vaults(vault_id),
  source_sha256 TEXT NOT NULL,
  entries_count INTEGER NOT NULL,
  categories_count INTEGER NOT NULL,
  goals_count INTEGER NOT NULL,
  recurring_count INTEGER NOT NULL,
  challenges_count INTEGER NOT NULL,
  deleted_count INTEGER NOT NULL,
  receipts_count INTEGER NOT NULL,
  income_minor INTEGER NOT NULL,
  expense_minor INTEGER NOT NULL,
  completed_at_ms INTEGER NOT NULL
)''',
  ];

  /// Always run [store.stageSnapshot] first, preserving the raw original.
  /// A changed snapshot for the same vault is forbidden; never overwrite
  /// already-staged financial records or merge accounts automatically.
  Future<NormalizedImportReport> stage(
      String vaultId, Map<String, Object?> source) async {
    final preflight = const WaffraLegacySnapshotInspector().inspect(source);
    final checksum = strict.WaffraLegacyPreflight.inspect(source);
    if (!preflight.canStage || !checksum.canStage) {
      throw StateError('Legacy validation failed; no data was changed.');
    }
    final shadow = await store.stageSnapshot(vaultId, source);
    if (shadow.sourceSha256 != checksum.sourceSha256) {
      throw StateError('Source changed between migration checks.');
    }

    final keys = <String, String>{
      'entries': 'normalized_entries',
      'waffra_categories_v24': 'normalized_categories',
      'waffra_goals_v24': 'normalized_goals',
      'waffra_recurring_v24': 'normalized_recurring',
      'waffra_challenges_v1': 'normalized_challenges',
    };
    final importedCounts = <String, int>{};
    var receiptReferences = 0;

    await store.transaction(() async {
      for (final sql in _ddl) {
        await store.customStatement(sql);
      }

      final existing = await store.customSelect(
        'SELECT source_sha256 FROM normalized_imports WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).get();
      if (existing.isNotEmpty) {
        if (existing.single.read<String>('source_sha256') != checksum.sourceSha256) {
          throw StateError('Another financial snapshot is already normalized.');
        }
        // Revalidate every count even on no-op retries.
        await _verify(vaultId, preflight);
        return;
      }

      for (final entry in keys.entries) {
        final raw = source[entry.key];
        final records = raw == null
            ? <dynamic>[]
            : jsonDecode(raw as String) as List<dynamic>;
        for (final item in records) {
          if (item is! Map) throw StateError('Invalid typed source record.');
          final value = Map<String, dynamic>.from(item);
          await _insert(entry.key, vaultId, value);
          if (entry.key == 'entries') {
            final paths = WaffraLegacySnapshotInspector.receiptPaths(
              value['receiptPath'],
            );
            final id = _string(value, 'id');
            for (var i = 0; i < paths.length; i++) {
              await store.customStatement(
                'INSERT INTO normalized_receipts '
                '(vault_id,entry_id,position,local_file_path) VALUES (?,?,?,?)',
                [vaultId, id, i, paths[i]],
              );
            }
            receiptReferences += paths.length;
          }
        }
        importedCounts[entry.key] = records.length;
      }

      for (final trashKey in const [
        'waffra_deleted_categories_v1',
        'waffra_deleted_goals_v1',
        'waffra_deleted_recurring_v1',
      ]) {
        final records = source[trashKey] == null
            ? <dynamic>[]
            : jsonDecode(source[trashKey] as String) as List<dynamic>;
        for (var i = 0; i < records.length; i++) {
          final item = Map<String, dynamic>.from(records[i] as Map);
          final payloadKey = switch (trashKey) {
            'waffra_deleted_categories_v1' => 'category',
            'waffra_deleted_goals_v1' => 'goal',
            _ => 'recurring'
          };
          final payload = Map<String, dynamic>.from(item[payloadKey] as Map);
          await store.customStatement('''
INSERT INTO normalized_deleted(vault_id,source_key,source_index,entity_id,
deleted_at_original_iso,original_json) VALUES (?,?,?,?,?,?)
''', [
            vaultId, trashKey, i, _string(payload, 'id'),
            _string(item, 'deletedAt'), jsonEncode(item),
          ]);
        }
      }

      final deletedCount = const [
        'waffra_deleted_categories_v1',
        'waffra_deleted_goals_v1',
        'waffra_deleted_recurring_v1',
      ].fold<int>(0, (sum, key) => sum + (preflight.counts[key] ?? 0));
      await store.customStatement('''
INSERT INTO normalized_imports(vault_id,source_sha256,entries_count,
categories_count,goals_count,recurring_count,challenges_count,deleted_count,
receipts_count,income_minor,expense_minor,completed_at_ms)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
''', [
        vaultId, checksum.sourceSha256,
        importedCounts['entries'] ?? 0,
        importedCounts['waffra_categories_v24'] ?? 0,
        importedCounts['waffra_goals_v24'] ?? 0,
        importedCounts['waffra_recurring_v24'] ?? 0,
        importedCounts['waffra_challenges_v1'] ?? 0,
        deletedCount, receiptReferences, preflight.incomeMinor,
        preflight.expenseMinor, DateTime.now().millisecondsSinceEpoch,
      ]);
      await _verify(vaultId, preflight);
    });

    return _report(vaultId, checksum.sourceSha256);
  }

  Future<void> _insert(String key, String vaultId, Map<String, dynamic> v) async {
    final original = jsonEncode(v);
    switch (key) {
      case 'entries':
        final date = _string(v, 'date');
        await store.customStatement('''
INSERT INTO normalized_entries(vault_id,entry_id,title,category_snapshot,
amount_minor,is_income,occurred_original_iso,occurred_local_date,receipt_raw,
original_json) VALUES (?,?,?,?,?,?,?,?,?,?)
''', [
          vaultId, _string(v, 'id'), _string(v, 'title'),
          _string(v, 'category'),
          _minor(v, 'amount'), v['income'] == true ? 1 : 0,
          date, date.substring(0, 10), v['receiptPath'], original,
        ]);
      case 'waffra_categories_v24':
        await store.customStatement('''
INSERT INTO normalized_categories(vault_id,category_id,name,parent_id,
is_income,budget_minor,original_json) VALUES (?,?,?,?,?,?,?)
''', [
          vaultId, _string(v, 'id'), _string(v, 'name'),
          v['parentId'] is String ? v['parentId'] : '',
          v['income'] == true ? 1 : 0, _minor(v, 'budget', optional: true),
          original,
        ]);
      case 'waffra_goals_v24':
        await store.customStatement('''
INSERT INTO normalized_goals(vault_id,goal_id,name,target_minor,
saved_minor,original_json) VALUES (?,?,?,?,?,?)
''', [
          vaultId, _string(v, 'id'), _string(v, 'name'),
          _minor(v, 'target'), _minor(v, 'saved', optional: true),
          original,
        ]);
      case 'waffra_recurring_v24':
        await store.customStatement('''
INSERT INTO normalized_recurring(vault_id,recurring_id,title,category_snapshot,
amount_minor,is_income,due_day,is_active,start_original_iso,original_json)
VALUES (?,?,?,?,?,?,?,?,?,?)
''', [
          vaultId, _string(v, 'id'), _string(v, 'title'),
          _string(v, 'category'), _minor(v, 'amount'),
          v['income'] == true ? 1 : 0, v['day'],
          v['active'] != false ? 1 : 0, _string(v, 'startAt'), original,
        ]);
      case 'waffra_challenges_v1':
        await store.customStatement('''
INSERT INTO normalized_challenges(vault_id,challenge_id,title,daily_amount_minor,
days,completed_days,last_done_iso,original_json) VALUES (?,?,?,?,?,?,?,?)
''', [
          vaultId, _string(v, 'id'), _string(v, 'title'),
          _minor(v, 'dailyAmount'), v['days'] ?? 30,
          v['completedDays'] ?? 0, v['lastDone'], original,
        ]);
      default:
        throw StateError('Unsupported typed collection.');
    }
  }

  static String _string(Map<String, dynamic> value, String field) {
    final result = value[field];
    if (result is! String) throw StateError('Invalid field: $field');
    return result;
  }

  static int _minor(Map<String, dynamic> value, String field,
      {bool optional = false}) {
    final raw = value[field];
    if (raw == null && optional) return 0;
    final result = WaffraLegacySnapshotInspector.amountToHalalas(raw);
    if (result == null) throw StateError('Unrepresentable amount: $field');
    return result;
  }

  Future<void> _verify(String vaultId, WaffraLegacyPreflight preflight) async {
    const checks = <String, String>{
      'entries': 'normalized_entries',
      'waffra_categories_v24': 'normalized_categories',
      'waffra_goals_v24': 'normalized_goals',
      'waffra_recurring_v24': 'normalized_recurring',
      'waffra_challenges_v1': 'normalized_challenges',
    };
    for (final check in checks.entries) {
      final n = await _count(check.value, vaultId);
      if (n != (preflight.counts[check.key] ?? 0)) {
        throw StateError('Typed snapshot parity failed: ${check.key}');
      }
    }
    final expectedDeleted = const [
      'waffra_deleted_categories_v1',
      'waffra_deleted_goals_v1',
      'waffra_deleted_recurring_v1',
    ].fold<int>(0, (sum, k) => sum + (preflight.counts[k] ?? 0));
    if (await _count('normalized_deleted', vaultId) != expectedDeleted ||
        await _count('normalized_receipts', vaultId) != preflight.receiptReferences) {
      throw StateError('Receipt/trash parity check failed.');
    }
    final sums = await store.customSelect('''
SELECT COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0)
AS income_minor,
COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0)
AS expense_minor FROM normalized_entries WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingle();
    if (sums.read<int>('income_minor') != preflight.incomeMinor ||
        sums.read<int>('expense_minor') != preflight.expenseMinor) {
      throw StateError('Normalized income/expense totals do not match.');
    }
  }

  Future<int> _count(String table, String vaultId) async {
    // This table name is internal, never user-supplied.
    final row = await store.customSelect(
      'SELECT count(*) AS total FROM $table WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return row.read<int>('total');
  }

  Future<NormalizedImportReport> _report(String vaultId, String digest) async {
    final r = await store.customSelect(
      'SELECT * FROM normalized_imports WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return NormalizedImportReport(
      sourceSha256: digest,
      entries: r.read<int>('entries_count'),
      categories: r.read<int>('categories_count'),
      goals: r.read<int>('goals_count'),
      recurring: r.read<int>('recurring_count'),
      challenges: r.read<int>('challenges_count'),
      trash: r.read<int>('deleted_count'),
      receipts: r.read<int>('receipts_count'),
      incomeMinor: r.read<int>('income_minor'),
      expenseMinor: r.read<int>('expense_minor'),
    );
  }

  Future<List<NormalizedLedgerEntry>> readEntries(String vaultId) async {
    final rows = await store.customSelect(
      'SELECT entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_original_iso FROM normalized_entries WHERE vault_id = ? '
      'ORDER BY occurred_local_date DESC,entry_id',
      variables: [Variable.withString(vaultId)],
    ).get();
    return [
      for (final row in rows)
        NormalizedLedgerEntry(
          id: row.read<String>('entry_id'),
          title: row.read<String>('title'),
          categorySnapshot: row.read<String>('category_snapshot'),
          amountMinor: row.read<int>('amount_minor'),
          income: row.read<int>('is_income') == 1,
          dateIso: row.read<String>('occurred_original_iso'),
        ),
    ];
  }
}

class NormalizedLedgerEntry {
  const NormalizedLedgerEntry({
    required this.id,
    required this.title,
    required this.categorySnapshot,
    required this.amountMinor,
    required this.income,
    required this.dateIso,
  });
  final String id, title, categorySnapshot, dateIso;
  final int amountMinor;
  final bool income;
}

class NormalizedImportReport {
  const NormalizedImportReport({
    required this.sourceSha256,
    required this.entries,
    required this.categories,
    required this.goals,
    required this.recurring,
    required this.challenges,
    required this.trash,
    required this.receipts,
    required this.incomeMinor,
    required this.expenseMinor,
  });
  final String sourceSha256;
  final int entries, categories, goals, recurring, challenges, trash, receipts;
  final int incomeMinor, expenseMinor;
}

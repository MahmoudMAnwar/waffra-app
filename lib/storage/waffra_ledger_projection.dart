import 'dart:convert';

import 'package:drift/drift.dart';

import 'legacy_financial_snapshot.dart';
import 'waffra_encrypted_store.dart';

/// Lossless, read-only-to-the-UI projection of an already verified shadow
/// snapshot. Operates inside the *encrypted* SQLite database and never touches
/// SharedPreferences, receipt files, Firebase or main.dart.
extension WaffraLedgerProjection on WaffraEncryptedStore {
  Future<WaffraProjectionReport> buildRelationalProjection(String vaultId) async {
    if (vaultId.trim().isEmpty) throw ArgumentError.value(vaultId, 'vaultId');
    final journals = await customSelect(
      'SELECT source_sha256, source_count, income_minor, expense_minor, '
      'receipt_references FROM shadow_migrations WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).get();
    if (journals.length != 1) {
      throw StateError('Expected exactly one verified shadow migration.');
    }
    final journal = journals.single;
    final digest = journal.read<String>('source_sha256');
    final expectedRows = journal.read<int>('source_count');
    final expectedIncome = journal.read<int>('income_minor');
    final expectedExpense = journal.read<int>('expense_minor');
    final expectedReceipts = journal.read<int>('receipt_references');
    final source = await customSelect(
      'SELECT source_key, source_index, source_value_json '
      'FROM shadow_records WHERE vault_id = ? ORDER BY source_key, source_index',
      variables: [Variable.withString(vaultId)],
    ).get();
    if (source.length != expectedRows) {
      throw StateError('Source snapshot count changed; refusing projection.');
    }

    await transaction(() async {
      await _createProjectionTables(this);
      final existing = await customSelect(
        'SELECT source_sha256 FROM projection_runs WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).get();
      if (existing.isNotEmpty) {
        if (existing.length != 1 ||
            existing.single.read<String>('source_sha256') != digest) {
          throw StateError('Different projection already exists for this vault.');
        }
      } else {
        for (final row in source) {
          final key = row.read<String>('source_key');
          final index = row.read<int>('source_index');
          final json = row.read<String>('source_value_json');
          final raw = jsonDecode(json);
          if (key == 'entries') {
            final data = _object(raw);
            final id = _id(data);
            final iso = data['date'] as String;
            final value = _minor(data['amount']);
            final income = data['income'] == true;
            await customStatement('''
INSERT INTO ledger_entries(vault_id,entry_id,title,category_snapshot,
amount_minor,is_income,occurred_iso,occurred_local_date,receipt_raw,source_json)
VALUES (?,?,?,?,?,?,?,?,?,?)
''', [
              vaultId, id, '${data['title'] ?? ''}',
              '${data['category'] ?? 'أخرى'}', value, income ? 1 : 0,
              iso, iso.substring(0, 10), data['receiptPath'], json,
            ]);
            final path = data['receiptPath'];
            final paths = WaffraLegacySnapshotInspector.receiptPaths(path);
            for (var position = 0; position < paths.length; position++) {
              await customStatement('''
INSERT INTO entry_receipts(vault_id,entry_id,position,legacy_absolute_path)
VALUES (?,?,?,?)
''', [vaultId, id, position, paths[position]]);
            }
          } else if (key == 'waffra_categories_v24' ||
              key == 'waffra_deleted_categories_v1') {
            final deleted = key == 'waffra_deleted_categories_v1';
            final record = _object(raw);
            final data = deleted ? _object(record['category']) : record;
            await customStatement('''
INSERT INTO categories(vault_id,category_id,source_bucket,name,icon,
color_argb,is_income,parent_id,budget_minor,alert_percent,deleted_at,
source_json) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
''', [
              vaultId, _id(data), key, '${data['name'] ?? ''}',
              '${data['icon'] ?? 'category'}',
              (data['color'] as num?)?.toInt() ?? 0xFF087A54,
              data['income'] == true ? 1 : 0,
              '${data['parentId'] ?? ''}', _minor(data['budget'] ?? 0),
              (data['alertPercent'] as num?)?.toInt() ?? 80,
              deleted ? record['deletedAt'] : null, json,
            ]);
          } else if (key == 'waffra_goals_v24' ||
              key == 'waffra_deleted_goals_v1') {
            final deleted = key == 'waffra_deleted_goals_v1';
            final record = _object(raw);
            final data = deleted ? _object(record['goal']) : record;
            await customStatement('''
INSERT INTO saving_goals(vault_id,goal_id,source_bucket,name,target_minor,
saved_minor,deleted_at,source_json) VALUES (?,?,?,?,?,?,?,?)
''', [
              vaultId, _id(data), key, '${data['name'] ?? ''}',
              _minor(data['target']), _minor(data['saved'] ?? 0),
              deleted ? record['deletedAt'] : null, json,
            ]);
          } else if (key == 'waffra_recurring_v24' ||
              key == 'waffra_deleted_recurring_v1') {
            final deleted = key == 'waffra_deleted_recurring_v1';
            final record = _object(raw);
            final data = deleted ? _object(record['recurring']) : record;
            await customStatement('''
INSERT INTO recurring_bills(vault_id,recurring_id,source_bucket,title,
category_snapshot,amount_minor,is_income,due_day,is_active,start_at,
deleted_at,source_json) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
''', [
              vaultId, _id(data), key, '${data['title'] ?? ''}',
              '${data['category'] ?? 'أخرى'}', _minor(data['amount']),
              data['income'] == true ? 1 : 0,
              (data['day'] as num?)?.toInt() ?? 1,
              data['active'] == false ? 0 : 1,
              data['startAt'], deleted ? record['deletedAt'] : null, json,
            ]);
          } else if (key == 'waffra_challenges_v1') {
            final data = _object(raw);
            await customStatement('''
INSERT INTO saving_challenges(vault_id,challenge_id,title,
daily_amount_minor,days,completed_days,last_done,source_json)
VALUES (?,?,?,?,?,?,?,?)
''', [
              vaultId, _id(data), '${data['title'] ?? ''}',
              _minor(data['dailyAmount']),
              (data['days'] as num?)?.toInt() ?? 30,
              (data['completedDays'] as num?)?.toInt() ?? 0,
              data['lastDone'], json,
            ]);
          } else if (key == 'waffra_recurring_postponed_v1' ||
              key == 'waffra_learned_merchants_v1') {
            final item = _object(raw);
            await customStatement('''
INSERT INTO vault_key_values(vault_id,source_bucket,item_key,item_json)
VALUES (?,?,?,?)
''', [vaultId, key, '${item['key']}', json]);
          } else if (key == 'waffra_sms_hashes_v1') {
            await customStatement('''
INSERT INTO sms_dedupe_hashes(vault_id,source_index,message_hash)
VALUES (?,?,?)
''', [vaultId, index, raw as String]);
          } else {
            await customStatement('''
INSERT INTO vault_settings(vault_id,source_key,source_json)
VALUES (?,?,?)
''', [vaultId, key, json]);
          }
        }
        await customStatement('''
INSERT INTO projection_runs(vault_id,source_sha256,source_count,
income_minor,expense_minor,receipt_references,completed_at_ms)
VALUES (?,?,?,?,?,?,?)
''', [
          vaultId, digest, expectedRows, expectedIncome, expectedExpense,
          expectedReceipts, DateTime.now().millisecondsSinceEpoch,
        ]);
      }
      await _verifyProjection(this, vaultId, expectedIncome,
          expectedExpense, expectedReceipts);
    });

    final entries = await customSelect(
      'SELECT count(*) AS n FROM ledger_entries WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return WaffraProjectionReport(
      sourceSha256: digest,
      stagedSourceRecords: source.length,
      ledgerEntries: entries.read<int>('n'),
      incomeMinor: expectedIncome,
      expenseMinor: expectedExpense,
      receiptReferences: expectedReceipts,
    );
  }

  /// Exact original JSON (not a reserialized model) for parity/rollback audits.
  Future<List<String>> readOriginalEntryJson(String vaultId) async {
    final rows = await customSelect(
      'SELECT source_json FROM ledger_entries WHERE vault_id = ? ORDER BY rowid',
      variables: [Variable.withString(vaultId)],
    ).get();
    return rows.map((r) => r.read<String>('source_json')).toList();
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw StateError('Invalid staged JSON object.');
  return Map<String, dynamic>.from(value);
}

String _id(Map<String, dynamic> obj) {
  final value = obj['id'];
  if (value is! String || value.trim().isEmpty) {
    throw StateError('Missing financial entity ID.');
  }
  return value;
}

int _minor(Object? amount) {
  final value = WaffraLegacySnapshotInspector.amountToHalalas(amount);
  if (value == null) throw StateError('Unrepresentable financial amount.');
  return value;
}

Future<void> _createProjectionTables(WaffraEncryptedStore db) async {
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS ledger_entries(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
entry_id TEXT NOT NULL, title TEXT NOT NULL, category_snapshot TEXT NOT NULL,
amount_minor INTEGER NOT NULL CHECK(amount_minor>=0),
is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
occurred_iso TEXT NOT NULL, occurred_local_date TEXT NOT NULL,
receipt_raw TEXT, source_json TEXT NOT NULL, PRIMARY KEY(vault_id,entry_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS entry_receipts(
vault_id TEXT NOT NULL, entry_id TEXT NOT NULL, position INTEGER NOT NULL,
legacy_absolute_path TEXT NOT NULL, PRIMARY KEY(vault_id,entry_id,position),
FOREIGN KEY(vault_id,entry_id) REFERENCES ledger_entries(vault_id,entry_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS categories(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
category_id TEXT NOT NULL, source_bucket TEXT NOT NULL,
name TEXT NOT NULL, icon TEXT NOT NULL, color_argb INTEGER NOT NULL,
is_income INTEGER NOT NULL CHECK(is_income IN (0,1)), parent_id TEXT NOT NULL,
budget_minor INTEGER NOT NULL CHECK(budget_minor>=0),
alert_percent INTEGER NOT NULL, deleted_at TEXT, source_json TEXT NOT NULL,
PRIMARY KEY(vault_id,source_bucket,category_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS saving_goals(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
goal_id TEXT NOT NULL,source_bucket TEXT NOT NULL,
name TEXT NOT NULL,target_minor INTEGER NOT NULL CHECK(target_minor>0),
saved_minor INTEGER NOT NULL CHECK(saved_minor>=0),
deleted_at TEXT,source_json TEXT NOT NULL,
PRIMARY KEY(vault_id,source_bucket,goal_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS recurring_bills(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
recurring_id TEXT NOT NULL,source_bucket TEXT NOT NULL,
title TEXT NOT NULL,category_snapshot TEXT NOT NULL,
amount_minor INTEGER NOT NULL CHECK(amount_minor>=0),
is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
is_active INTEGER NOT NULL CHECK(is_active IN (0,1)),
start_at TEXT,deleted_at TEXT,source_json TEXT NOT NULL,
PRIMARY KEY(vault_id,source_bucket,recurring_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS saving_challenges(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
challenge_id TEXT NOT NULL,title TEXT NOT NULL,
daily_amount_minor INTEGER NOT NULL CHECK(daily_amount_minor>=0),
days INTEGER NOT NULL, completed_days INTEGER NOT NULL,last_done TEXT,
source_json TEXT NOT NULL,PRIMARY KEY(vault_id,challenge_id))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS vault_key_values(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
source_bucket TEXT NOT NULL,item_key TEXT NOT NULL,item_json TEXT NOT NULL,
PRIMARY KEY(vault_id,source_bucket,item_key))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS sms_dedupe_hashes(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
source_index INTEGER NOT NULL,message_hash TEXT NOT NULL,
PRIMARY KEY(vault_id,source_index))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS vault_settings(
vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
source_key TEXT NOT NULL,source_json TEXT NOT NULL,
PRIMARY KEY(vault_id,source_key))
''');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS projection_runs(
vault_id TEXT PRIMARY KEY NOT NULL REFERENCES shadow_vaults(vault_id),
source_sha256 TEXT NOT NULL,source_count INTEGER NOT NULL,
income_minor INTEGER NOT NULL,expense_minor INTEGER NOT NULL,
receipt_references INTEGER NOT NULL,completed_at_ms INTEGER NOT NULL)
''');
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_ledger_month ON ledger_entries(vault_id,occurred_local_date)');
}

Future<void> _verifyProjection(
  WaffraEncryptedStore db, String vaultId,
  int expectedIncome, int expectedExpense, int expectedReceipts,
) async {
  final row = await db.customSelect('''
SELECT
COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0) AS income,
COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0) AS expense
FROM ledger_entries WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingle();
  final receipts = await db.customSelect(
    'SELECT count(*) AS n FROM entry_receipts WHERE vault_id = ?',
    variables: [Variable.withString(vaultId)],
  ).getSingle();
  if (row.read<int>('income') != expectedIncome ||
      row.read<int>('expense') != expectedExpense ||
      receipts.read<int>('n') != expectedReceipts) {
    throw StateError('Relational projection financial parity failed.');
  }
}

class WaffraProjectionReport {
  const WaffraProjectionReport({
    required this.sourceSha256,
    required this.stagedSourceRecords,
    required this.ledgerEntries,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.receiptReferences,
  });
  final String sourceSha256;
  final int stagedSourceRecords;
  final int ledgerEntries;
  final int incomeMinor;
  final int expenseMinor;
  final int receiptReferences;
}

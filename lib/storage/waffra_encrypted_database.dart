import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Encrypted local SQLite proof of concept, deliberately NOT wired into
/// Waffra's current load()/persist() or Firebase.
///
/// V1 uses Drift's transaction/query engine and hand-authored SQL statements.
/// Follow-up work can generate typed Drift tables/DAOs; no codegen is required
/// for the stand-alone proof-of-concept tests.
///
/// SECURITY: The sqlite3mc hook in pubspec.yaml is mandatory. We verify the
/// runtime cipher pragma **outside** assert(), so release builds fail closed
/// if an unencrypted regular SQLite library is accidentally bundled.
final class WaffraEncryptedVaultDatabase extends GeneratedDatabase {
  WaffraEncryptedVaultDatabase._(QueryExecutor executor) : super(executor);

  static WaffraEncryptedVaultDatabase open({
    required File file,
    required String passphrase,
  }) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError.value('', 'passphrase', 'Key must not be empty');
    }

    final executor = NativeDatabase.createInBackground(
      file,
      logStatements: false,
      setup: (rawDb) {
        // Regular SQLite silently ignores unknown PRAGMA key. Fail closed!
        if (rawDb.select('PRAGMA cipher;').isEmpty) {
          throw StateError('Encrypted SQLite engine is unavailable');
        }

        final escaped = passphrase.replaceAll("'", "''");
        rawDb.execute("PRAGMA key = '$escaped';");

        // Force the driver to read the encrypted database header, including
        // when reopening an existing file. Wrong keys must not appear valid.
        rawDb.select('SELECT count(*) FROM sqlite_master;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );

    return WaffraEncryptedVaultDatabase._(executor);
  }

  @override
  int get schemaVersion => 1;

  /// The PoC uses manually versioned DDL rather than generated Drift tables.
  /// DO NOT call Drift's default migrator: use the explicit DDL below.
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          for (final statement in _v1Ddl) {
            await customStatement(statement);
          }
        },
        onUpgrade: (m, oldVersion, newVersion) async {
          // Never delete/rebuild a finance database on a version mismatch.
          throw StateError('Unsupported encrypted vault schema migration');
        },
      );

  /// Tests and future shadow import only. The current app remains bound to
  /// SharedPreferences until explicit verification and cutover.
  Future<void> createVault(String vaultId) async {
    _assertVaultId(vaultId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT OR IGNORE INTO vaults '
      '(vault_id, display_label, currency_code, sync_enabled, created_at_ms, updated_at_ms) '
      "VALUES (?, '', 'SAR', 0, ?, ?)",
      [vaultId, now, now],
    );
  }

  /// Inserts a single immutable test/import record with a deterministic ID.
  /// Reject duplicate IDs rather than silently replacing other transactions.
  Future<void> insertShadowEntry({
    required String vaultId,
    required String entryId,
    required String title,
    required String categorySnapshot,
    required int amountMinor,
    required bool isIncome,
    required String occurredIso,
    required String localDate,
  }) async {
    _assertVaultId(vaultId);
    if (entryId.isEmpty || amountMinor < 0 ||
        !RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(localDate)) {
      throw ArgumentError('Invalid shadow entry');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final sarText =
        '${amountMinor ~/ 100}.${(amountMinor % 100).toString().padLeft(2, '0')}';
    await customStatement(
      'INSERT INTO ledger_entries '
      '(vault_id, entry_id, title, category_name_snapshot, amount_minor, '
      'original_amount_text, is_income, occurred_at_original_iso, '
      'occurred_local_date, created_at_ms, updated_at_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        vaultId,
        entryId,
        title,
        categorySnapshot,
        amountMinor,
        sarText,
        isIncome ? 1 : 0,
        occurredIso,
        localDate,
        now,
        now,
      ],
    );
  }

  Future<int> countActiveEntries(String vaultId) async {
    _assertVaultId(vaultId);
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM ledger_entries '
      'WHERE vault_id = ? AND deleted_at_ms IS NULL',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return row.read<int>('n');
  }

  Future<({int income, int expense})> sumBySide(String vaultId) async {
    _assertVaultId(vaultId);
    final rows = await customSelect(
      'SELECT '
      'COALESCE(SUM(CASE WHEN is_income = 1 THEN amount_minor ELSE 0 END), 0) AS income, '
      'COALESCE(SUM(CASE WHEN is_income = 0 THEN amount_minor ELSE 0 END), 0) AS expense '
      'FROM ledger_entries WHERE vault_id = ? AND deleted_at_ms IS NULL',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return (income: rows.read<int>('income'), expense: rows.read<int>('expense'));
  }

  /// Verifies DB internals independently of any self-reported row count.
  Future<void> verifyIntegrity() async {
    final row = await customSelect('PRAGMA integrity_check;').getSingle();
    if (row.read<String>('integrity_check') != 'ok') {
      throw StateError('Vault database integrity check failed');
    }
    final fk = await customSelect('PRAGMA foreign_key_check;').get();
    if (fk.isNotEmpty) {
      throw StateError('Vault database has broken foreign keys');
    }
  }

  static void _assertVaultId(String vaultId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(vaultId)) {
      throw ArgumentError.value(vaultId, 'vaultId', 'Invalid vault identifier');
    }
  }

  // Mirrors the logical v1 schema in docs/architecture/schema_v1.sql.
  // Schema remains internal to this isolated proof; app writes are disabled.
  static const List<String> _v1Ddl = [
    '''
CREATE TABLE vaults (
  vault_id TEXT PRIMARY KEY NOT NULL,
  owner_uid TEXT,
  display_label TEXT NOT NULL DEFAULT '',
  currency_code TEXT NOT NULL DEFAULT 'SAR' CHECK (currency_code = 'SAR'),
  sync_enabled INTEGER NOT NULL DEFAULT 0 CHECK (sync_enabled IN (0,1)),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)''',
    '''
CREATE TABLE ledger_entries (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  entry_id TEXT NOT NULL,
  legacy_entry_id TEXT,
  title TEXT NOT NULL,
  category_name_snapshot TEXT NOT NULL,
  category_id TEXT,
  amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
  original_amount_text TEXT NOT NULL,
  is_income INTEGER NOT NULL CHECK (is_income IN (0,1)),
  occurred_at_original_iso TEXT NOT NULL,
  occurred_local_date TEXT NOT NULL,
  legacy_receipt_raw TEXT,
  legacy_snapshot_json TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  deleted_at_ms INTEGER,
  PRIMARY KEY (vault_id, entry_id)
)''',
    'CREATE INDEX idx_ledger_vault_date ON ledger_entries (vault_id, occurred_local_date DESC, entry_id)',
    'CREATE INDEX idx_ledger_vault_category ON ledger_entries (vault_id, category_name_snapshot, is_income)',
    '''
CREATE TABLE categories (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  category_id TEXT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color_argb INTEGER NOT NULL,
  is_income INTEGER NOT NULL CHECK (is_income IN (0,1)),
  parent_id TEXT NOT NULL DEFAULT '',
  budget_minor INTEGER NOT NULL CHECK (budget_minor >= 0),
  alert_percent INTEGER NOT NULL CHECK (alert_percent BETWEEN 0 AND 100),
  legacy_snapshot_json TEXT,
  trash_snapshot_json TEXT,
  deleted_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, category_id)
)''',
    'CREATE INDEX idx_categories_vault_parent ON categories (vault_id, parent_id, deleted_at_ms)',
    '''
CREATE TABLE saving_goals (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  goal_id TEXT NOT NULL,
  name TEXT NOT NULL,
  target_minor INTEGER NOT NULL CHECK (target_minor > 0),
  saved_minor INTEGER NOT NULL CHECK (saved_minor >= 0),
  original_target_text TEXT NOT NULL,
  original_saved_text TEXT NOT NULL,
  legacy_snapshot_json TEXT,
  trash_snapshot_json TEXT,
  deleted_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, goal_id)
)''',
    '''
CREATE TABLE saving_challenges (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  challenge_id TEXT NOT NULL,
  title TEXT NOT NULL,
  daily_amount_minor INTEGER NOT NULL CHECK (daily_amount_minor >= 0),
  days INTEGER NOT NULL CHECK (days > 0),
  completed_days INTEGER NOT NULL CHECK (completed_days >= 0),
  last_done_original_iso TEXT,
  legacy_snapshot_json TEXT,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, challenge_id)
)''',
    '''
CREATE TABLE recurring_bills (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  recurring_id TEXT NOT NULL,
  title TEXT NOT NULL,
  category_name_snapshot TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
  original_amount_text TEXT NOT NULL,
  is_income INTEGER NOT NULL CHECK (is_income IN (0,1)),
  due_day INTEGER NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  is_active INTEGER NOT NULL CHECK (is_active IN (0,1)),
  start_at_original_iso TEXT NOT NULL,
  legacy_snapshot_json TEXT,
  trash_snapshot_json TEXT,
  deleted_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, recurring_id)
)''',
    'CREATE INDEX idx_recurring_vault_active ON recurring_bills (vault_id, is_active, deleted_at_ms)',
    '''
CREATE TABLE recurring_postponements (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  generated_entry_id TEXT NOT NULL,
  postponed_to_original_iso TEXT NOT NULL,
  PRIMARY KEY (vault_id, generated_entry_id)
)''',
    '''
CREATE TABLE receipt_assets (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  receipt_id TEXT NOT NULL,
  legacy_absolute_path TEXT,
  relative_path TEXT,
  content_sha256 TEXT,
  file_exists_at_import INTEGER NOT NULL DEFAULT 0 CHECK (file_exists_at_import IN (0,1)),
  missing_reason TEXT,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, receipt_id)
)''',
    '''
CREATE TABLE entry_receipts (
  vault_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  receipt_id TEXT NOT NULL,
  position INTEGER NOT NULL CHECK (position >= 0),
  PRIMARY KEY (vault_id, entry_id, position),
  UNIQUE (vault_id, entry_id, receipt_id),
  FOREIGN KEY (vault_id, entry_id) REFERENCES ledger_entries(vault_id, entry_id) ON DELETE RESTRICT,
  FOREIGN KEY (vault_id, receipt_id) REFERENCES receipt_assets(vault_id, receipt_id) ON DELETE RESTRICT
)''',
    '''
CREATE TABLE merchant_category_rules (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  merchant_key TEXT NOT NULL,
  category_name TEXT NOT NULL,
  PRIMARY KEY (vault_id, merchant_key)
)''',
    '''
CREATE TABLE sms_dedupe_hashes (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  message_hash TEXT NOT NULL,
  PRIMARY KEY (vault_id, message_hash)
)''',
    '''
CREATE TABLE vault_settings (
  vault_id TEXT PRIMARY KEY NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  monthly_budget_minor INTEGER NOT NULL DEFAULT 0 CHECK (monthly_budget_minor >= 0),
  monthly_budget_enabled INTEGER NOT NULL DEFAULT 0 CHECK (monthly_budget_enabled IN (0,1)),
  recurring_reminders_enabled INTEGER NOT NULL DEFAULT 0 CHECK (recurring_reminders_enabled IN (0,1)),
  updated_at_ms INTEGER NOT NULL
)''',
    '''
CREATE TABLE financial_audit_events (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  event_id TEXT NOT NULL,
  subject_kind TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  details_json TEXT NOT NULL,
  occurred_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, event_id)
)''',
    '''
CREATE TABLE migration_runs (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  migration_id TEXT NOT NULL,
  source_version TEXT NOT NULL,
  source_sha256 TEXT NOT NULL,
  target_schema_version INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('STAGING','VERIFIED','COMMITTED','FAILED')),
  manifest_json TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  completed_at_ms INTEGER,
  PRIMARY KEY (vault_id, migration_id),
  UNIQUE (vault_id, source_sha256, target_schema_version)
)''',
    '''
CREATE TABLE migration_quarantine (
  vault_id TEXT NOT NULL,
  migration_id TEXT NOT NULL,
  source_key TEXT NOT NULL,
  source_index INTEGER NOT NULL,
  raw_json TEXT NOT NULL,
  error_code TEXT NOT NULL,
  PRIMARY KEY (vault_id, migration_id, source_key, source_index),
  FOREIGN KEY (vault_id, migration_id) REFERENCES migration_runs(vault_id, migration_id) ON DELETE RESTRICT
)''',
    '''
CREATE TABLE sync_outbox (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  mutation_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  entity_kind TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('UPSERT','DELETE')),
  local_version INTEGER NOT NULL CHECK (local_version > 0),
  payload_json TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  acknowledged_at_ms INTEGER,
  retry_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (vault_id, mutation_id)
)''',
    'CREATE INDEX idx_sync_pending ON sync_outbox (vault_id, acknowledged_at_ms, created_at_ms)',
    '''
CREATE TABLE sync_cursors (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  device_id TEXT NOT NULL,
  remote_cursor TEXT,
  last_success_at_ms INTEGER,
  PRIMARY KEY (vault_id, device_id)
)''',
  ];
}

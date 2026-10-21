-- Waffra candidate local SQLite schema, v1 (architecture artifact only)
-- NOT executed in production. Drift must own actual create/upgrade migrations.
-- CRITICAL: SQLite is NOT encrypted by this script. Require a tested SQLCipher
-- driver + Keystore/Keychain-managed keys before financial-data cutover.
-- All money is integral SAR halalas; original legacy numeric text is preserved.
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS vaults (
  vault_id TEXT PRIMARY KEY NOT NULL,
  owner_uid TEXT,
  display_label TEXT NOT NULL DEFAULT '',
  currency_code TEXT NOT NULL DEFAULT 'SAR' CHECK (currency_code = 'SAR'),
  sync_enabled INTEGER NOT NULL DEFAULT 0 CHECK (sync_enabled IN (0,1)),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS ledger_entries (
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
);

CREATE INDEX IF NOT EXISTS idx_ledger_vault_date
ON ledger_entries (vault_id, occurred_local_date DESC, entry_id);
CREATE INDEX IF NOT EXISTS idx_ledger_vault_category
ON ledger_entries (vault_id, category_name_snapshot, is_income);

CREATE TABLE IF NOT EXISTS categories (
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
);
CREATE INDEX IF NOT EXISTS idx_categories_vault_parent
ON categories (vault_id, parent_id, deleted_at_ms);
-- Deliberately no unique(name) or required category FK: old data may have
-- duplicate names or orphaned historical category string snapshots.

CREATE TABLE IF NOT EXISTS saving_goals (
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
);
-- Existing builds have only a current goal savings value, NOT old deposit events.

CREATE TABLE IF NOT EXISTS saving_challenges (
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
);

CREATE TABLE IF NOT EXISTS recurring_bills (
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
);
CREATE INDEX IF NOT EXISTS idx_recurring_vault_active
ON recurring_bills (vault_id, is_active, deleted_at_ms);

CREATE TABLE IF NOT EXISTS recurring_postponements (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  generated_entry_id TEXT NOT NULL,
  postponed_to_original_iso TEXT NOT NULL,
  PRIMARY KEY (vault_id, generated_entry_id)
);

CREATE TABLE IF NOT EXISTS receipt_assets (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  receipt_id TEXT NOT NULL,
  legacy_absolute_path TEXT,
  relative_path TEXT,
  content_sha256 TEXT,
  file_exists_at_import INTEGER NOT NULL DEFAULT 0 CHECK (file_exists_at_import IN (0,1)),
  missing_reason TEXT,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, receipt_id)
);

CREATE TABLE IF NOT EXISTS entry_receipts (
  vault_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  receipt_id TEXT NOT NULL,
  position INTEGER NOT NULL CHECK (position >= 0),
  PRIMARY KEY (vault_id, entry_id, position),
  UNIQUE (vault_id, entry_id, receipt_id),
  FOREIGN KEY (vault_id, entry_id) REFERENCES ledger_entries(vault_id, entry_id) ON DELETE RESTRICT,
  FOREIGN KEY (vault_id, receipt_id) REFERENCES receipt_assets(vault_id, receipt_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS merchant_category_rules (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  merchant_key TEXT NOT NULL,
  category_name TEXT NOT NULL,
  PRIMARY KEY (vault_id, merchant_key)
);

CREATE TABLE IF NOT EXISTS sms_dedupe_hashes (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  message_hash TEXT NOT NULL,
  PRIMARY KEY (vault_id, message_hash)
);

CREATE TABLE IF NOT EXISTS vault_settings (
  vault_id TEXT PRIMARY KEY NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  monthly_budget_minor INTEGER NOT NULL DEFAULT 0 CHECK (monthly_budget_minor >= 0),
  monthly_budget_enabled INTEGER NOT NULL DEFAULT 0 CHECK (monthly_budget_enabled IN (0,1)),
  recurring_reminders_enabled INTEGER NOT NULL DEFAULT 0 CHECK (recurring_reminders_enabled IN (0,1)),
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS financial_audit_events (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  event_id TEXT NOT NULL,
  subject_kind TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  details_json TEXT NOT NULL,
  occurred_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, event_id)
);
-- Audit restore/reset events prospectively; never invent legacy goal contributions.

CREATE TABLE IF NOT EXISTS migration_runs (
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
);

CREATE TABLE IF NOT EXISTS migration_quarantine (
  vault_id TEXT NOT NULL,
  migration_id TEXT NOT NULL,
  source_key TEXT NOT NULL,
  source_index INTEGER NOT NULL,
  raw_json TEXT NOT NULL,
  error_code TEXT NOT NULL,
  PRIMARY KEY (vault_id, migration_id, source_key, source_index),
  FOREIGN KEY (vault_id, migration_id) REFERENCES migration_runs(vault_id, migration_id) ON DELETE RESTRICT
);
-- Quarantined PII remains in the encrypted local DB, never logs or cloud.

CREATE TABLE IF NOT EXISTS sync_outbox (
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
);
CREATE INDEX IF NOT EXISTS idx_sync_pending
ON sync_outbox (vault_id, acknowledged_at_ms, created_at_ms);

CREATE TABLE IF NOT EXISTS sync_cursors (
  vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE RESTRICT,
  device_id TEXT NOT NULL,
  remote_cursor TEXT,
  last_success_at_ms INTEGER,
  PRIMARY KEY (vault_id, device_id)
);

PRAGMA user_version = 1;

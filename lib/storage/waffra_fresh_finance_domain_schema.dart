import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';

/// Versioned, additive finance-domain schema for an already verified SQLCipher
/// connection. No call here selects the app's active source or migrates data.
/// Tables for suggestions/history are intentionally EMPTY until the user saves
/// or confirms real records. Pure UI preferences never become finance rows.
abstract final class WaffraFreshFinanceDomainSchema {
  static const version = 2;

  static const domainTables = <String>[
    'fresh_finance_standalone_budgets',
    'fresh_finance_standalone_allocations',
    'fresh_finance_named_budgets',
    'fresh_finance_budget_allocations',
    'fresh_finance_goal_opening_balances',
    'fresh_finance_goal_wallet_movements',
    'fresh_finance_goal_due_settlements',
    'fresh_finance_project_wallets',
    'fresh_finance_project_wallet_links',
    'fresh_finance_confirmed_subscriptions',
    'fresh_finance_saved_scenarios',
    'fresh_finance_ai_threads',
    'fresh_finance_ai_messages',
    'fresh_finance_price_observations',
    'fresh_finance_notification_events',
  ];

  /// Caller MUST run inside the same encrypted SQLite transaction as the
  /// original fresh-vault bootstrap. Repeated calls never erase data.
  static Future<void> install(WaffraEncryptedStore store) async {
    final original = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (original.length != 1 || original.single.read<int>('schema_version') != 1) {
      throw StateError('Fresh SQLCipher source is not verified.');
    }
    await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_domain_revision(
  slot TEXT PRIMARY KEY NOT NULL CHECK(slot='domain'),
  version INTEGER NOT NULL CHECK(version > 0)
)''');
    final current = await store.customSelect(
      "SELECT version FROM fresh_finance_domain_revision WHERE slot='domain'",
    ).get();
    final previous = current.isEmpty ? null : current.single.read<int>('version');
    if (current.length > 1 || (previous != null &&
        previous != 1 && previous != version)) {
      throw StateError('Unknown finance-domain schema revision.');
    }
    if (current.isNotEmpty) {
      // A marked SQLCipher vault with a missing domain table is tampered or
      // interrupted. NEVER recreate an empty replacement and claim success.
      // The first two tables are V2 additions. A V1 candidate may lack
      // only these; missing ANY other table is corruption, not a migration.
      for (final table in (previous==1?domainTables.skip(2):domainTables)) {
        final exists = await store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(table)],
        ).get();
        if (exists.length != 1) {
          throw StateError('Versioned encrypted finance domain is incomplete.');
        }
      }
      if(previous==1){
       // Reject interrupted/partial future schema instead of adopting it.
       for(final table in const <String>[
        'fresh_finance_standalone_budgets',
        'fresh_finance_standalone_allocations',
       ]){
        final exists=await store.customSelect(
         "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
         variables:[Variable.withString(table)]).get();
        if(exists.isNotEmpty)throw StateError(
         'Unversioned standalone budget upgrade is incomplete.');
       }
      }
    }
    if (current.isEmpty) {
      // No version marker + pre-existing domain rows is an incomplete or
      // externally modified database. Never silently adopt or overwrite it.
      for (final table in domainTables) {
        final exists = await store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(table)],
        ).get();
        if (exists.isNotEmpty) {
          throw StateError('Unversioned finance-domain schema found.');
        }
      }
    }

    const statements = <String>[
      // Independent budgets are NOT category children and cannot cascade
      // when a user deletes or renames a category.
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_standalone_budgets(
  budget_id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL CHECK(length(trim(name)) > 0 AND length(name) <= 80),
  monthly_limit_minor INTEGER NOT NULL CHECK(monthly_limit_minor > 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  alert_percent INTEGER NOT NULL DEFAULT 80 CHECK(alert_percent BETWEEN 1 AND 100),
  archived_at_iso TEXT,
  created_at_iso TEXT NOT NULL,
  source_json TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_standalone_allocations(
  allocation_id TEXT PRIMARY KEY NOT NULL,
  budget_id TEXT NOT NULL REFERENCES fresh_finance_standalone_budgets(budget_id)
    ON DELETE RESTRICT,
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  assigned_at_iso TEXT NOT NULL,
  explicitly_confirmed INTEGER NOT NULL CHECK(explicitly_confirmed=1),
  UNIQUE(entry_id)
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_named_budgets(
  budget_id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL CHECK(length(trim(name)) > 0),
  category_id TEXT NOT NULL REFERENCES fresh_finance_categories(category_id)
    ON DELETE RESTRICT,
  monthly_limit_minor INTEGER NOT NULL CHECK(monthly_limit_minor > 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  alert_percent INTEGER NOT NULL DEFAULT 80 CHECK(alert_percent BETWEEN 1 AND 100),
  created_at_iso TEXT NOT NULL,
  legacy_category_id TEXT UNIQUE,
  source_json TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_budget_allocations(
  allocation_id TEXT PRIMARY KEY NOT NULL,
  budget_id TEXT NOT NULL REFERENCES fresh_finance_named_budgets(budget_id)
    ON DELETE RESTRICT,
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  explicitly_confirmed INTEGER NOT NULL CHECK(explicitly_confirmed = 1),
  assigned_at_iso TEXT NOT NULL,
  UNIQUE(budget_id, entry_id)
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_goal_opening_balances(
  goal_id TEXT PRIMARY KEY NOT NULL REFERENCES fresh_finance_goals(goal_id)
    ON DELETE RESTRICT,
  saved_minor INTEGER NOT NULL CHECK(saved_minor >= 0),
  source_digest TEXT NOT NULL CHECK(length(source_digest) >= 16),
  witnessed_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_goal_wallet_movements(
  movement_id TEXT PRIMARY KEY NOT NULL,
  goal_id TEXT NOT NULL REFERENCES fresh_finance_goals(goal_id)
    ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK(kind IN
    ('fund','release','transfer_in','transfer_out','due_debit')),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  idempotency_key TEXT NOT NULL UNIQUE,
  linked_entry_id TEXT REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  occurred_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_goal_due_settlements(
  due_key TEXT PRIMARY KEY NOT NULL,
  goal_id TEXT NOT NULL REFERENCES fresh_finance_goals(goal_id)
    ON DELETE RESTRICT,
  recurring_id TEXT NOT NULL REFERENCES fresh_finance_recurring(recurring_id)
    ON DELETE RESTRICT,
  entry_id TEXT NOT NULL UNIQUE REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  goal_wallet_minor INTEGER NOT NULL CHECK(goal_wallet_minor >= 0),
  current_cash_minor INTEGER NOT NULL CHECK(current_cash_minor >= 0),
  confirmed_at_iso TEXT NOT NULL,
  CHECK(amount_minor = goal_wallet_minor + current_cash_minor)
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_project_wallets(
  project_id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL CHECK(length(trim(title)) > 0),
  target_minor INTEGER NOT NULL DEFAULT 0 CHECK(target_minor >= 0),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)),
  created_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_project_wallet_links(
  project_id TEXT NOT NULL REFERENCES fresh_finance_project_wallets(project_id)
    ON DELETE RESTRICT,
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  allocation_minor INTEGER NOT NULL CHECK(allocation_minor > 0),
  PRIMARY KEY(project_id,entry_id)
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_confirmed_subscriptions(
  subscription_id TEXT PRIMARY KEY NOT NULL,
  merchant_label TEXT NOT NULL CHECK(length(trim(merchant_label)) > 0),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  renewal_day INTEGER NOT NULL CHECK(renewal_day BETWEEN 1 AND 31),
  status TEXT NOT NULL CHECK(status IN ('confirmed','paused','cancelled')),
  confirmed_at_iso TEXT NOT NULL,
  linked_category_id TEXT REFERENCES fresh_finance_categories(category_id)
    ON DELETE RESTRICT
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_saved_scenarios(
  scenario_id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN
    ('affordability','before_spend','safety_buffer','seasonal','challenge')),
  name TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  saved_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_ai_threads(
  thread_id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  user_opted_in INTEGER NOT NULL CHECK(user_opted_in = 1),
  created_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_ai_messages(
  message_id TEXT PRIMARY KEY NOT NULL,
  thread_id TEXT NOT NULL REFERENCES fresh_finance_ai_threads(thread_id)
    ON DELETE RESTRICT,
  role TEXT NOT NULL CHECK(role IN ('user','assistant')),
  content TEXT NOT NULL,
  occurred_at_iso TEXT NOT NULL
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_price_observations(
  observation_id TEXT PRIMARY KEY NOT NULL,
  instrument TEXT NOT NULL,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  price_micro INTEGER NOT NULL CHECK(price_micro >= 0),
  source_label TEXT NOT NULL,
  observed_at_iso TEXT NOT NULL,
  UNIQUE(instrument,currency_code,source_label,observed_at_iso)
)''',
      '''
CREATE TABLE IF NOT EXISTS fresh_finance_notification_events(
  event_id TEXT PRIMARY KEY NOT NULL,
  recurring_id TEXT REFERENCES fresh_finance_recurring(recurring_id)
    ON DELETE RESTRICT,
  goal_id TEXT REFERENCES fresh_finance_goals(goal_id)
    ON DELETE RESTRICT,
  scheduled_at_iso TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN
    ('scheduled','delivered','cancelled','failed')),
  CHECK(recurring_id IS NOT NULL OR goal_id IS NOT NULL)
)''',
    ];
    for (final statement in statements) {
      await store.customStatement(statement);
    }
    await store.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_standalone_allocations_budget '
      'ON fresh_finance_standalone_allocations(budget_id)',
    );
    await store.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_budget_allocations_entry '
      'ON fresh_finance_budget_allocations(entry_id)',
    );
    await store.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_goal_movements_goal '
      'ON fresh_finance_goal_wallet_movements(goal_id,occurred_at_iso)',
    );
    await store.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_goal_due_recurring '
      'ON fresh_finance_goal_due_settlements(recurring_id)',
    );
    await store.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_subscription_status '
      'ON fresh_finance_confirmed_subscriptions(status,renewal_day)',
    );
    for (final table in domainTables) {
      final tableExists = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
      ).get();
      if (tableExists.length != 1) {
        throw StateError('Missing required encrypted finance table: $table');
      }
    }
    final violations = await store.customSelect('PRAGMA foreign_key_check').get();
    if (violations.isNotEmpty) {
      throw StateError('Encrypted finance contains foreign-key violations.');
    }
    if (current.isEmpty) {
      await store.customStatement(
        "INSERT INTO fresh_finance_domain_revision(slot,version) VALUES('domain',?)",
        [version],
      );
    }else if(previous==1){
      final originalMarker=await store.customSelect(
       "SELECT version FROM fresh_finance_domain_revision WHERE slot='domain'",
      ).getSingle();
      if(originalMarker.read<int>('version')!=1){
       throw StateError('Domain changed during standalone budget upgrade.');
      }
      await store.customStatement(
       "UPDATE fresh_finance_domain_revision SET version=? "
       "WHERE slot='domain' AND version=1",[version]);
    }
  }

  static Future<void> requireReady(WaffraEncryptedStore store) async {
    final present = await store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_domain_revision'",
    ).get();
    if (present.length != 1) {
      throw StateError('Finance domain was not initialized.');
    }
    final marker = await store.customSelect(
      "SELECT version FROM fresh_finance_domain_revision WHERE slot='domain'",
    ).get();
    if (marker.length != 1 || marker.single.read<int>('version') != version) {
      throw StateError('Unsupported SQLCipher finance domain revision.');
    }
    for (final table in domainTables) {
      final exists = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(table)],
      ).get();
      if (exists.length != 1) {
        throw StateError('An encrypted finance-domain table is missing.');
      }
    }
  }
}

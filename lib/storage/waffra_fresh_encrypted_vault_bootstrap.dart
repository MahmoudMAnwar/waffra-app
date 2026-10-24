import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';

/// Conservative eligibility check for a new installation.
/// Never equate "0 transactions" with "nothing worth preserving".
enum WaffraFirstRunDecision {
  freshCandidate,
  legacyNeedsReview,
  encryptedVaultAlreadyPresent,
  inconsistentState,
}

class WaffraFirstRunClassifier {
  const WaffraFirstRunClassifier();

  // Only non-financial settings are allowed during an otherwise empty
  // onboarding. All other keys, including identity, goals and empty JSON
  // finance arrays, require a separate legacy inspection instead.
  static const allowedAppearanceKeys = <String>{
    'waffra_language',
    'waffra_dark_mode',
    'waffra_hide_amounts',
    'waffra_allow_screenshots',
    'waffra_animation_level',
  };

  WaffraFirstRunDecision decide({
    required Map<String, Object?> existingPreferences,
    required bool encryptedVaultFileExists,
    required bool activationMarkerExists,
    bool independentWriterMayBeActive = false,
  }) {
    if (independentWriterMayBeActive ||
        (activationMarkerExists && !encryptedVaultFileExists)) {
      return WaffraFirstRunDecision.inconsistentState;
    }
    if (encryptedVaultFileExists) {
      // Never overwrite/reinitialize a preexisting encrypted file, regardless
      // of whether the activation marker was written before a process kill.
      return activationMarkerExists
          ? WaffraFirstRunDecision.encryptedVaultAlreadyPresent
          : WaffraFirstRunDecision.inconsistentState;
    }

    final keys = existingPreferences.keys.toSet();
    if (keys.any(WaffraLegacyPreflight.allKeys.contains) ||
        keys.difference(allowedAppearanceKeys).isNotEmpty) {
      return WaffraFirstRunDecision.legacyNeedsReview;
    }
    // Validate even the allowlisted values, rather than silently resetting
    // corrupted settings and creating a new financial data source.
    final language = existingPreferences['waffra_language'];
    if (language != null && language != 'en' && language != 'ar') {
      return WaffraFirstRunDecision.legacyNeedsReview;
    }
    for (final key in const [
      'waffra_dark_mode',
      'waffra_hide_amounts',
      'waffra_allow_screenshots',
    ]) {
      final value = existingPreferences[key];
      if (value != null && value is! bool) {
        return WaffraFirstRunDecision.legacyNeedsReview;
      }
    }
    final motion = existingPreferences['waffra_animation_level'];
    if (motion != null &&
        !const {'off', 'reduced', 'balanced', 'full'}.contains(motion)) {
      return WaffraFirstRunDecision.legacyNeedsReview;
    }
    return WaffraFirstRunDecision.freshCandidate;
  }
}

class WaffraFreshVaultResult {
  const WaffraFreshVaultResult({
    required this.isNew,
    required this.schemaVersion,
  });

  final bool isNew;
  final int schemaVersion;
}

/// Creates EMPTY tables inside an already-open SQLCipher-encrypted TEST vault.
///
/// This does not inspect the real device, create encryption keys, switch
/// main.dart to SQLite, or write a SharedPreferences activation marker.
/// freshCandidate is valid only for a checked, single-writer first run.
/// Production requires a durable selector + crash recovery and coordination
/// with the quick-add Android widget before calling this for real user data.
class WaffraFreshEncryptedVaultBootstrap {
  const WaffraFreshEncryptedVaultBootstrap({
    required this.store,
    this.experimentalEnabled = false,
  });

  static const schemaVersion = 1;
  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  Future<WaffraFreshVaultResult> initialize({
    required WaffraFirstRunDecision decision,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Fresh encrypted vault bootstrap is disabled by default.');
    }
    if (decision != WaffraFirstRunDecision.freshCandidate) {
      throw StateError('Existing or ambiguous data cannot be initialized as new.');
    }

    return store.transaction(() async {
      // The existing migration sandbox must never be silently treated as
      // an empty live vault. This check executes within the transaction.
      final staged = await store.customSelect(
        'SELECT count(*) AS n FROM shadow_migrations',
      ).getSingle();
      final shadowVaults = await store.customSelect(
        'SELECT count(*) AS n FROM shadow_vaults',
      ).getSingle();
      if (staged.read<int>('n') != 0 ||
          shadowVaults.read<int>('n') != 0) {
        throw StateError('Encrypted database already contains staged finance.');
      }

      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_meta(
  slot TEXT PRIMARY KEY NOT NULL CHECK(slot='primary'),
  schema_version INTEGER NOT NULL CHECK(schema_version > 0),
  initialized_at_ms INTEGER NOT NULL
)''');
      final existing = await store.customSelect(
        "SELECT schema_version FROM fresh_finance_meta WHERE slot = 'primary'",
      ).get();
      if (existing.isNotEmpty &&
          (existing.length != 1 ||
              existing.single.read<int>('schema_version') != schemaVersion)) {
        throw StateError('Unknown or incompatible encrypted finance schema.');
      }

      // Explicit PK, FK and money constraints. No sample transactions,
      // categories or goals are injected into a real finance vault.
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_entries(
  entry_id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  category_id TEXT,
  category_snapshot TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
  is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
  occurred_iso TEXT NOT NULL,
  receipt_count INTEGER NOT NULL DEFAULT 0 CHECK(receipt_count >= 0),
  source_json TEXT NOT NULL
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_categories(
  category_id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  parent_id TEXT,
  is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
  budget_minor INTEGER NOT NULL DEFAULT 0 CHECK(budget_minor >= 0),
  source_json TEXT NOT NULL
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_goals(
  goal_id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  target_minor INTEGER NOT NULL CHECK(target_minor > 0),
  saved_minor INTEGER NOT NULL CHECK(saved_minor >= 0),
  source_json TEXT NOT NULL
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_recurring(
  recurring_id TEXT PRIMARY KEY NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
  is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
  due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
  source_json TEXT NOT NULL
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_receipts(
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_filename TEXT NOT NULL UNIQUE,
  sha256_hex TEXT NOT NULL,
  PRIMARY KEY(entry_id, position)
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_settings(
  setting_key TEXT PRIMARY KEY NOT NULL,
  value_json TEXT NOT NULL
)''');
      // Portable restore and live encrypted suggestions share this typed table.
      // A fresh candidate starts empty; no legacy preference is imported.
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_custom_goals(
  position INTEGER PRIMARY KEY CHECK(position >= 0),
  suggestion TEXT NOT NULL
)''');
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_sms_hashes(
  message_hash TEXT PRIMARY KEY NOT NULL
)''');
      await store.customStatement('''
CREATE INDEX IF NOT EXISTS idx_fresh_finance_date
ON fresh_finance_entries(occurred_iso)''');

      if (existing.isEmpty) {
        await store.customStatement(
          'INSERT INTO fresh_finance_meta(slot,schema_version,initialized_at_ms) '
          'VALUES (?,?,?)',
          ['primary', schemaVersion, DateTime.now().millisecondsSinceEpoch],
        );
      }

      // A freshly initialized vault must contain NO financial transactions
      // or prior user entities. Reinitialization is idempotent and non-erasing.
      if (existing.isEmpty) {
        for (final table in const [
          'fresh_finance_entries',
          'fresh_finance_categories',
          'fresh_finance_goals',
          'fresh_finance_recurring',
          'fresh_finance_receipts',
          'fresh_finance_settings',
          'fresh_finance_sms_hashes',
          'fresh_finance_custom_goals',
        ]) {
          final count = await store.customSelect(
            'SELECT count(*) AS n FROM $table',
          ).getSingle();
          if (count.read<int>('n') != 0) {
            throw StateError('Fresh vault contains unexpected stored records.');
          }
        }
      }
      return WaffraFreshVaultResult(
        isNew: existing.isEmpty,
        schemaVersion: schemaVersion,
      );
    });
  }
}

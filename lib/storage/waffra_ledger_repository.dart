import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_financial_write_gate.dart';

/// Future app-facing financial repository, NOT active in main.dart.
/// Reads and writes only an isolated encrypted SQLite working projection.
/// The existing SharedPreferences ledger and verified import remain untouched.
abstract class WaffraLedgerRepository {
  Future<void> prepareVerifiedVault(String vaultId);
  Future<List<WaffraLedgerItem>> entries(String vaultId, {bool includeDeleted = false});
  Future<WaffraLedgerBalances> balances(String vaultId);
  Future<void> saveEntry(String vaultId, WaffraLedgerItem item, {required int expectedVersion});
  Future<void> deleteEntry(String vaultId, String id, {required int expectedVersion});
  Future<void> restoreEntry(String vaultId, String id, {required int expectedVersion});
}

class WaffraLedgerItem {
  const WaffraLedgerItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amountMinor,
    required this.isIncome,
    required this.occurredIso,
    required this.version,
    this.deleted = false,
  });
  final String id, title, category, occurredIso;
  final int amountMinor, version;
  final bool isIncome, deleted;

  WaffraLedgerItem copyWith({
    String? title,
    String? category,
    int? amountMinor,
    bool? isIncome,
    String? occurredIso,
    int? version,
    bool? deleted,
  }) => WaffraLedgerItem(
    id: id, title: title ?? this.title, category: category ?? this.category,
    amountMinor: amountMinor ?? this.amountMinor,
    isIncome: isIncome ?? this.isIncome,
    occurredIso: occurredIso ?? this.occurredIso,
    version: version ?? this.version, deleted: deleted ?? this.deleted,
  );
}

class WaffraLedgerBalances {
  const WaffraLedgerBalances({required this.incomeMinor, required this.expenseMinor});
  final int incomeMinor, expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
}

/// Explicit experimental opt-in needed even for local shadow changes.
/// This does NOT imply user consent to cloud sync or legacy storage cutover.
class WaffraDraftSqliteLedgerRepository implements WaffraLedgerRepository {
  WaffraDraftSqliteLedgerRepository({
    required this.database,
    required this.gate,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore database;
  final WaffraFinancialWriteGate gate;
  final bool experimentalEnabled;

  void _requireEnabled() {
    if (!experimentalEnabled) {
      throw StateError('Encrypted working ledger is disabled by default.');
    }
  }

  static void _id(String value, String name) {
    if (value.trim().isEmpty || value.length > 128 || value.contains('/')) {
      throw ArgumentError('Invalid $name.');
    }
  }

  static void _validate(WaffraLedgerItem item) {
    _id(item.id, 'entry id');
    if (item.title.trim().isEmpty || item.category.trim().isEmpty ||
        item.title.length > 4096 || item.category.length > 256 ||
        item.amountMinor < 0 || item.version < 1) {
      throw ArgumentError('Invalid ledger entry.');
    }
    // Preserve the user's calendar day without UTC conversion or silently
    // replacing an invalid legacy date with DateTime.now().
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T|$)').firstMatch(item.occurredIso);
    if (m == null || DateTime.tryParse(item.occurredIso) == null) {
      throw ArgumentError('Invalid original transaction date.');
    }
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError('Impossible calendar date.');
    }
  }

  static const _ddl = [
    '''
CREATE TABLE IF NOT EXISTS working_ledger_entries (
 vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
 entry_id TEXT NOT NULL,
 title TEXT NOT NULL,
 category_snapshot TEXT NOT NULL,
 amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
 is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
 occurred_iso TEXT NOT NULL,
 local_version INTEGER NOT NULL CHECK(local_version > 0),
 is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1)),
 PRIMARY KEY(vault_id,entry_id)
)''',
    '''
CREATE TABLE IF NOT EXISTS working_ledger_preparations (
 vault_id TEXT PRIMARY KEY REFERENCES shadow_vaults(vault_id),
 source_sha256 TEXT NOT NULL,
 initial_count INTEGER NOT NULL,
 initial_income_minor INTEGER NOT NULL,
 initial_expense_minor INTEGER NOT NULL
)''',
  ];

  Future<void> _requirePrepared(String vaultId) async {
    _requireEnabled();
    _id(vaultId, 'vault');
    final present = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='working_ledger_preparations'",
    ).get();
    if (present.isEmpty) throw StateError('Vault working ledger is not prepared.');
    final row = await database.customSelect(
      'SELECT source_sha256 FROM working_ledger_preparations WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingleOrNull();
    if (row == null) throw StateError('This vault has not been verified and prepared.');
  }

  /// Starts from the already verified, immutable relational projection.
  /// A separate table prevents any mutation of the original migration audit.
  /// Never reads/writes SharedPreferences and never initiates any network call.
  @override
  Future<void> prepareVerifiedVault(String vaultId) async {
    _requireEnabled();
    _id(vaultId, 'vault');
    await gate.runWrite(() => database.transaction(() async {
      final original = await database.customSelect('''
SELECT source_sha256, source_count, income_minor, expense_minor
FROM projection_runs WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingleOrNull();
      if (original == null) {
        throw StateError('Verified legacy projection missing for this vault.');
      }
      final sourceSha = original.read<String>('source_sha256');
      for (final ddl in _ddl) {
        await database.customStatement(ddl);
      }
      final existing = await database.customSelect(
        'SELECT source_sha256 FROM working_ledger_preparations WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (existing != null) {
        if (existing.read<String>('source_sha256') != sourceSha) {
          throw StateError('Working vault source checksum changed.');
        }
        return;
      }
      // Copy one time only, preserving historical dates and integer halalas.
      await database.customStatement('''
INSERT INTO working_ledger_entries
(vault_id,entry_id,title,category_snapshot,amount_minor,is_income,
 occurred_iso,local_version,is_deleted)
SELECT vault_id,entry_id,title,category_snapshot,amount_minor,is_income,
       occurred_iso,1,0
FROM ledger_entries WHERE vault_id = ?
''', [vaultId]);

      final count = await database.customSelect('''
SELECT COUNT(*) AS n,
  COALESCE(SUM(CASE WHEN is_income = 1 THEN amount_minor ELSE 0 END),0) AS inc,
  COALESCE(SUM(CASE WHEN is_income = 0 THEN amount_minor ELSE 0 END),0) AS exp
FROM working_ledger_entries WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingle();
      final verified = await database.customSelect('''
SELECT COUNT(*) AS n FROM ledger_entries WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingle();
      if (count.read<int>('n') != verified.read<int>('n') ||
          count.read<int>('inc') != original.read<int>('income_minor') ||
          count.read<int>('exp') != original.read<int>('expense_minor')) {
        throw StateError('Ledger seed parity mismatch: transaction rolled back.');
      }
      await database.customStatement('''
INSERT INTO working_ledger_preparations
(vault_id,source_sha256,initial_count,initial_income_minor,initial_expense_minor)
VALUES (?,?,?,?,?)
''', [
        vaultId, sourceSha, count.read<int>('n'),
        count.read<int>('inc'), count.read<int>('exp'),
      ]);
    }));
  }

  WaffraLedgerItem _mapRow(QueryRow row) => WaffraLedgerItem(
    id: row.read<String>('entry_id'),
    title: row.read<String>('title'),
    category: row.read<String>('category_snapshot'),
    amountMinor: row.read<int>('amount_minor'),
    isIncome: row.read<int>('is_income') == 1,
    occurredIso: row.read<String>('occurred_iso'),
    version: row.read<int>('local_version'),
    deleted: row.read<int>('is_deleted') == 1,
  );

  @override
  Future<List<WaffraLedgerItem>> entries(
    String vaultId, {bool includeDeleted = false}
  ) async {
    await _requirePrepared(vaultId);
    final rows = await database.customSelect('''
SELECT entry_id,title,category_snapshot,amount_minor,is_income,
 occurred_iso,local_version,is_deleted FROM working_ledger_entries
WHERE vault_id = ? AND (? = 1 OR is_deleted = 0)
ORDER BY occurred_iso DESC, entry_id
''', variables: [
      Variable.withString(vaultId), Variable.withInt(includeDeleted ? 1 : 0),
    ]).get();
    return rows.map(_mapRow).toList(growable: false);
  }

  @override
  Future<WaffraLedgerBalances> balances(String vaultId) async {
    await _requirePrepared(vaultId);
    final row = await database.customSelect('''
SELECT
COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0) AS inc,
COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0) AS exp
FROM working_ledger_entries WHERE vault_id = ? AND is_deleted = 0
''', variables: [Variable.withString(vaultId)]).getSingle();
    return WaffraLedgerBalances(
      incomeMinor: row.read<int>('inc'), expenseMinor: row.read<int>('exp'));
  }

  @override
  Future<void> saveEntry(
    String vaultId, WaffraLedgerItem item, {required int expectedVersion}
  ) async {
    _validate(item);
    if (item.deleted || expectedVersion < 0 || item.version != expectedVersion + 1) {
      throw ArgumentError('Wrong expected version or deleted item.');
    }
    await gate.runWrite(() async {
      await _requirePrepared(vaultId);
      await database.transaction(() async {
        final existing = await database.customSelect('''
SELECT local_version,is_deleted FROM working_ledger_entries
WHERE vault_id=? AND entry_id=?
''', variables: [
          Variable.withString(vaultId), Variable.withString(item.id),
        ]).getSingleOrNull();
        if (existing == null) {
          if (expectedVersion != 0) {
            throw StateError('New entry must start at version one.');
          }
          await database.customStatement('''
INSERT INTO working_ledger_entries
(vault_id,entry_id,title,category_snapshot,amount_minor,is_income,
 occurred_iso,local_version,is_deleted)
VALUES (?,?,?,?,?,?,?,?,0)
''', [
            vaultId, item.id, item.title, item.category, item.amountMinor,
            item.isIncome ? 1 : 0, item.occurredIso, item.version,
          ]);
        } else {
          if (existing.read<int>('local_version') != expectedVersion ||
              existing.read<int>('is_deleted') != 0) {
            throw StateError('Stale edit or deleted entry: refused.');
          }
          await database.customStatement('''
UPDATE working_ledger_entries SET title=?,category_snapshot=?,amount_minor=?,
 is_income=?,occurred_iso=?,local_version=?
WHERE vault_id=? AND entry_id=? AND local_version=? AND is_deleted=0
''', [
            item.title, item.category, item.amountMinor, item.isIncome ? 1 : 0,
            item.occurredIso, item.version, vaultId, item.id, expectedVersion,
          ]);
        }
      });
    });
  }

  Future<void> _changeDeletion(
    String vaultId, String id, {required int expectedVersion, required bool deleted}
  ) async {
    _id(id, 'entry id');
    if (expectedVersion < 1) throw ArgumentError('Invalid expected version.');
    await gate.runWrite(() async {
      await _requirePrepared(vaultId);
      await database.transaction(() async {
        final old = await database.customSelect('''
SELECT local_version,is_deleted FROM working_ledger_entries
WHERE vault_id=? AND entry_id=?
''', variables: [
          Variable.withString(vaultId), Variable.withString(id),
        ]).getSingleOrNull();
        if (old == null ||
            old.read<int>('local_version') != expectedVersion ||
            old.read<int>('is_deleted') == (deleted ? 1 : 0)) {
          throw StateError('Stale or duplicate deletion/restore request.');
        }
        await database.customStatement('''
UPDATE working_ledger_entries SET is_deleted=?, local_version=?
WHERE vault_id=? AND entry_id=? AND local_version=?
''', [deleted ? 1 : 0, expectedVersion + 1, vaultId, id, expectedVersion]);
      });
    });
  }

  @override
  Future<void> deleteEntry(String vaultId, String id, {required int expectedVersion}) =>
      _changeDeletion(vaultId, id, expectedVersion: expectedVersion, deleted: true);

  @override
  Future<void> restoreEntry(String vaultId, String id, {required int expectedVersion}) =>
      _changeDeletion(vaultId, id, expectedVersion: expectedVersion, deleted: false);
}

import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_financial_write_gate.dart';

class WaffraRecurringWorkingItem {
  const WaffraRecurringWorkingItem({
    required this.id,
    required this.day,
    required this.version,
    required this.active,
    required this.deleted,
    this.nextDueLocalDate,
  });
  final String id;
  final int day, version;
  final bool active, deleted;
  final String? nextDueLocalDate;
}

/// Isolated draft recurring-bill recovery state. The live scheduling engine,
/// SharedPreferences, history and cloud remain untouched. No transactions
/// are generated merely because an item is restored.
class WaffraDraftRecurringRecovery {
  WaffraDraftRecurringRecovery({
    required this.db,
    required this.gate,
    this.experimentalEnabled = false,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  final WaffraEncryptedStore db;
  final WaffraFinancialWriteGate gate;
  final bool experimentalEnabled;
  final DateTime Function() now;
  static const recyclePeriod = Duration(days: 30);

  void _validateEnabled(String vaultId) {
    if (!experimentalEnabled) {
      throw StateError('Recurring restore prototype is disabled.');
    }
    if (vaultId.trim().isEmpty || vaultId.length > 128 ||
        vaultId.contains('/')) {
      throw ArgumentError('Invalid local vault ID.');
    }
  }

  Future<void> _requirePrepared(String vaultId) async {
    _validateEnabled(vaultId);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='working_recurring_ready'",
    ).get();
    if (tables.isEmpty) throw StateError('Recurring snapshot is not prepared.');
    final row = await db.customSelect(
      'SELECT source_sha256 FROM working_recurring_ready WHERE vault_id=?',
      variables: [Variable.withString(vaultId)],
    ).getSingleOrNull();
    if (row == null) throw StateError('Recurring vault has not been prepared.');
  }

  /// New due date is a user-chosen *future calendar day*, without timezone
  /// conversion. Invalid dates such as 2026-02-30 are strictly rejected.
  String _futureLocalDate(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (m == null) throw ArgumentError('Select a valid next due date.');
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    final future = DateTime.utc(year, month, day);
    if (future.year != year || future.month != month || future.day != day) {
      throw ArgumentError('Impossible next due date.');
    }
    final clock = now();
    final today = DateTime.utc(clock.year, clock.month, clock.day);
    if (!future.isAfter(today)) {
      throw ArgumentError('The next due date must be in the future.');
    }
    return iso;
  }

  Future<void> prepareVerifiedVault(String vaultId) async {
    _validateEnabled(vaultId);
    await gate.runWrite(() => db.transaction(() async {
      final projectionTable = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='projection_runs'",
      ).get();
      if (projectionTable.isEmpty) throw StateError('Verified projection missing.');
      final source = await db.customSelect(
        'SELECT source_sha256 FROM projection_runs WHERE vault_id=?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (source == null) throw StateError('No verified snapshot for this vault.');
      final sha = source.read<String>('source_sha256');
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS working_recurring_items(
 vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
 recurring_id TEXT NOT NULL,
 original_json TEXT NOT NULL,
 due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
 is_active INTEGER NOT NULL CHECK(is_active IN (0,1)),
 is_deleted INTEGER NOT NULL CHECK(is_deleted IN (0,1)),
 deleted_at_ms INTEGER,
 next_due_local_date TEXT,
 local_version INTEGER NOT NULL CHECK(local_version>0),
 PRIMARY KEY(vault_id,recurring_id)
)''');
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS working_recurring_ready(
 vault_id TEXT PRIMARY KEY REFERENCES shadow_vaults(vault_id),
 source_sha256 TEXT NOT NULL
)''');
      final prev = await db.customSelect(
        'SELECT source_sha256 FROM working_recurring_ready WHERE vault_id=?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (prev != null) {
        if (prev.read<String>('source_sha256') != sha) {
          throw StateError('Recurring working snapshot checksum mismatch.');
        }
        return;
      }
      final rows = await db.customSelect('''
SELECT recurring_id,due_day,is_active,deleted_at,source_json
FROM recurring_bills WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).get();
      for (final row in rows) {
        final id = row.read<String>('recurring_id');
        if (id.trim().isEmpty || id.length > 128) {
          throw StateError('Invalid imported recurring ID.');
        }
        final deletedRaw = row.readNullable<String>('deleted_at');
        final date = deletedRaw == null ? null : DateTime.tryParse(deletedRaw);
        if (deletedRaw != null && date == null) {
          throw StateError('Bad recurring deletion timestamp.');
        }
        await db.customStatement('''
INSERT INTO working_recurring_items
(vault_id,recurring_id,original_json,due_day,is_active,is_deleted,
 deleted_at_ms,next_due_local_date,local_version)
VALUES (?,?,?,?,?,?,?,NULL,1)
''', [
          vaultId, id, row.read<String>('source_json'),
          row.read<int>('due_day'),
          deletedRaw == null ? row.read<int>('is_active') : 0,
          deletedRaw == null ? 0 : 1,
          date?.toUtc().millisecondsSinceEpoch,
        ]);
      }
      final count = await db.customSelect(
        'SELECT COUNT(*) AS n FROM working_recurring_items WHERE vault_id=?',
        variables: [Variable.withString(vaultId)],
      ).getSingle();
      if (count.read<int>('n') != rows.length) {
        throw StateError('Recurring working copy parity mismatch.');
      }
      await db.customStatement(
        'INSERT INTO working_recurring_ready(vault_id,source_sha256) VALUES (?,?)',
        [vaultId, sha],
      );
    }));
  }

  Future<List<WaffraRecurringWorkingItem>> items(
      String vaultId, {bool includeDeleted = false}) async {
    await _requirePrepared(vaultId);
    final rows = await db.customSelect('''
SELECT recurring_id,due_day,is_active,is_deleted,next_due_local_date,local_version
FROM working_recurring_items WHERE vault_id = ?
  AND (? = 1 OR is_deleted = 0)
ORDER BY recurring_id
''', variables: [
      Variable.withString(vaultId), Variable.withInt(includeDeleted ? 1 : 0),
    ]).get();
    return rows.map((r) => WaffraRecurringWorkingItem(
      id: r.read<String>('recurring_id'),
      day: r.read<int>('due_day'),
      active: r.read<int>('is_active') == 1,
      deleted: r.read<int>('is_deleted') == 1,
      version: r.read<int>('local_version'),
      nextDueLocalDate: r.readNullable<String>('next_due_local_date'),
    )).toList(growable: false);
  }

  /// Soft-delete only. Does NOT remove recurring-generated ledger entries.
  Future<void> delete(String vaultId, String id,
      {required int expectedVersion}) async {
    await _transition(vaultId, id,
        expectedVersion: expectedVersion, nextDate: null);
  }

  /// Require an explicit future next due date on every restore.
  Future<void> restore(String vaultId, String id, {
    required int expectedVersion,
    required String nextDueLocalDate,
  }) async {
    final date = _futureLocalDate(nextDueLocalDate);
    await _transition(vaultId, id,
        expectedVersion: expectedVersion, nextDate: date);
  }

  Future<void> _transition(String vaultId, String id, {
    required int expectedVersion, required String? nextDate,
  }) async {
    if (id.trim().isEmpty || id.length > 128 || expectedVersion < 1) {
      throw ArgumentError('Invalid recurring item or local version.');
    }
    final restore = nextDate != null;
    await gate.runWrite(() async {
      await _requirePrepared(vaultId);
      await db.transaction(() async {
        final item = await db.customSelect('''
SELECT local_version,is_deleted,deleted_at_ms FROM working_recurring_items
WHERE vault_id=? AND recurring_id=?
''', variables: [
          Variable.withString(vaultId), Variable.withString(id),
        ]).getSingleOrNull();
        if (item == null || item.read<int>('local_version') != expectedVersion ||
            (item.read<int>('is_deleted') == 1) != restore) {
          throw StateError('Stale or duplicate recurring action.');
        }
        if (!restore) {
          await db.customStatement('''
UPDATE working_recurring_items SET is_deleted=1,is_active=0,
 deleted_at_ms=?,next_due_local_date=NULL,local_version=?
WHERE vault_id=? AND recurring_id=? AND local_version=?
''', [
            now().toUtc().millisecondsSinceEpoch, expectedVersion + 1,
            vaultId, id, expectedVersion,
          ]);
          return;
        }
        final deletedMs = item.readNullable<int>('deleted_at_ms');
        if (deletedMs == null) throw StateError('No recurring delete timestamp.');
        final age = now().toUtc().difference(
          DateTime.fromMillisecondsSinceEpoch(deletedMs, isUtc: true));
        if (age.isNegative || age > recyclePeriod) {
          throw StateError('Recurring restore window expired.');
        }
        final chosenDay = int.parse(nextDate.substring(8, 10));
        await db.customStatement('''
UPDATE working_recurring_items SET is_deleted=0,is_active=1,
 deleted_at_ms=NULL,next_due_local_date=?,due_day=?,local_version=?
WHERE vault_id=? AND recurring_id=? AND local_version=?
''', [
          nextDate, chosenDay, expectedVersion + 1,
          vaultId, id, expectedVersion,
        ]);
      });
    });
  }
}

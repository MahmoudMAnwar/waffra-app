import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_financial_write_gate.dart';

enum WaffraRecoverableKind { goal, category }

class WaffraRecoverableRecord {
  const WaffraRecoverableRecord({
    required this.kind,
    required this.id,
    required this.allocatedMinor,
    required this.version,
    required this.deleted,
    this.deletedAtUtc,
  });
  final WaffraRecoverableKind kind;
  final String id;
  final int allocatedMinor, version;
  final bool deleted;
  final DateTime? deletedAtUtc;
}

/// Isolated proof-of-concept for approved 30-day goal/category recycle behavior.
/// No main.dart integration, no destructive purge and no production cutover.
/// The immutable legacy projection/source JSON always remain unchanged.
class WaffraDraftRecoverableRepository {
  WaffraDraftRecoverableRepository({
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

  void _enabled() {
    if (!experimentalEnabled) {
      throw StateError('Goal/category recovery prototype disabled.');
    }
  }

  static void _validateVault(String vaultId) {
    if (vaultId.trim().isEmpty || vaultId.length > 128 ||
        vaultId.contains('/')) {
      throw ArgumentError('Invalid local vault identity.');
    }
  }

  static String _kind(WaffraRecoverableKind kind) => kind.name;

  Future<void> _requirePrepared(String vaultId) async {
    _enabled();
    _validateVault(vaultId);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='working_recoverables'",
    ).get();
    if (tables.isEmpty) throw StateError('Recoverable working copy not prepared.');
    final row = await db.customSelect(
      'SELECT source_sha256 FROM working_recoverables_ready WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingleOrNull();
    if (row == null) throw StateError('Unverified or unprepared vault.');
  }

  static int? _deletedAt(Object? iso) {
    if (iso == null) return null;
    if (iso is! String || iso.trim().isEmpty) {
      throw StateError('Invalid legacy deletion timestamp.');
    }
    final date = DateTime.tryParse(iso);
    if (date == null) throw StateError('Invalid legacy deletion timestamp.');
    return date.toUtc().millisecondsSinceEpoch;
  }

  /// Copies active and trashed goals/categories from their verified relational
  /// projection. Duplicate IDs across active/trashed buckets fail closed and
  /// roll back the entire working copy; history is never rewritten.
  Future<void> prepareVerifiedVault(String vaultId) async {
    _enabled();
    _validateVault(vaultId);
    await gate.runWrite(() => db.transaction(() async {
      final exists = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='projection_runs'",
      ).get();
      if (exists.isEmpty) throw StateError('Verified projection schema missing.');
      final row = await db.customSelect(
        'SELECT source_sha256 FROM projection_runs WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (row == null) throw StateError('Unverified legacy vault.');
      final sha = row.read<String>('source_sha256');
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS working_recoverables(
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  record_kind TEXT NOT NULL CHECK(record_kind IN ('goal','category')),
  record_id TEXT NOT NULL,
  original_source_json TEXT NOT NULL,
  allocated_minor INTEGER NOT NULL CHECK(allocated_minor >= 0),
  local_version INTEGER NOT NULL CHECK(local_version > 0),
  is_deleted INTEGER NOT NULL CHECK(is_deleted IN (0,1)),
  deleted_at_ms INTEGER,
  PRIMARY KEY(vault_id,record_kind,record_id)
)''');
      await db.customStatement('''
CREATE TABLE IF NOT EXISTS working_recoverables_ready(
  vault_id TEXT PRIMARY KEY REFERENCES shadow_vaults(vault_id),
  source_sha256 TEXT NOT NULL
)''');
      final already = await db.customSelect(
        'SELECT source_sha256 FROM working_recoverables_ready WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (already != null) {
        if (already.read<String>('source_sha256') != sha) {
          throw StateError('Cannot seed a different snapshot into this vault.');
        }
        return;
      }
      final rows = <(String, String, String, int, int?)>[];
      final goals = await db.customSelect('''
SELECT goal_id, saved_minor, deleted_at, source_json
FROM saving_goals WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).get();
      for (final item in goals) {
        rows.add((
          'goal', item.read<String>('goal_id'), item.read<String>('source_json'),
          item.read<int>('saved_minor'), _deletedAt(item.readNullable<String>('deleted_at')),
        ));
      }
      final categories = await db.customSelect('''
SELECT category_id, budget_minor, deleted_at, source_json
FROM categories WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).get();
      for (final item in categories) {
        rows.add((
          'category', item.read<String>('category_id'),
          item.read<String>('source_json'), item.read<int>('budget_minor'),
          _deletedAt(item.readNullable<String>('deleted_at')),
        ));
      }
      for (final item in rows) {
        if (item.$2.trim().isEmpty || item.$2.length > 128) {
          throw StateError('Invalid imported recoverable entity ID.');
        }
        await db.customStatement('''
INSERT INTO working_recoverables(vault_id,record_kind,record_id,
original_source_json,allocated_minor,local_version,is_deleted,deleted_at_ms)
VALUES (?,?,?,?,?,1,?,?)
''', [
          vaultId, item.$1, item.$2, item.$3, item.$4,
          item.$5 == null ? 0 : 1, item.$5,
        ]);
      }
      final verified = await db.customSelect('''
SELECT COUNT(*) AS n FROM working_recoverables WHERE vault_id = ?
''', variables: [Variable.withString(vaultId)]).getSingle();
      if (verified.read<int>('n') != rows.length) {
        throw StateError('Recoverable working copy count mismatch.');
      }
      await db.customStatement('''
INSERT INTO working_recoverables_ready(vault_id,source_sha256) VALUES (?,?)
''', [vaultId, sha]);
    }));
  }

  Future<List<WaffraRecoverableRecord>> records(
    String vaultId, WaffraRecoverableKind kind,
    {bool includeDeleted = false}
  ) async {
    await _requirePrepared(vaultId);
    final rows = await db.customSelect('''
SELECT record_id,allocated_minor,local_version,is_deleted,deleted_at_ms
FROM working_recoverables
WHERE vault_id = ? AND record_kind = ?
  AND (? = 1 OR is_deleted = 0)
ORDER BY record_id
''', variables: [
      Variable.withString(vaultId), Variable.withString(_kind(kind)),
      Variable.withInt(includeDeleted ? 1 : 0),
    ]).get();
    return rows.map((row) {
      final timestamp = row.readNullable<int>('deleted_at_ms');
      return WaffraRecoverableRecord(
        kind: kind,
        id: row.read<String>('record_id'),
        allocatedMinor: row.read<int>('allocated_minor'),
        version: row.read<int>('local_version'),
        deleted: row.read<int>('is_deleted') == 1,
        deletedAtUtc: timestamp == null
            ? null : DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
      );
    }).toList(growable: false);
  }

  Future<void> delete(
    String vaultId, WaffraRecoverableKind kind, String id,
    {required int expectedVersion}
  ) async {
    await _transition(
      vaultId, kind, id, expectedVersion: expectedVersion, restore: false);
  }

  Future<void> restore(
    String vaultId, WaffraRecoverableKind kind, String id,
    {required int expectedVersion}
  ) async {
    await _transition(
      vaultId, kind, id, expectedVersion: expectedVersion, restore: true);
  }

  Future<void> _transition(
    String vaultId, WaffraRecoverableKind kind, String id, {
    required int expectedVersion, required bool restore,
  }) async {
    if (id.trim().isEmpty || id.length > 128 || expectedVersion < 1) {
      throw ArgumentError('Invalid recoverable record/version.');
    }
    await gate.runWrite(() async {
      await _requirePrepared(vaultId);
      await db.transaction(() async {
        final current = await db.customSelect('''
SELECT local_version,is_deleted,deleted_at_ms
FROM working_recoverables WHERE vault_id=? AND record_kind=? AND record_id=?
''', variables: [
          Variable.withString(vaultId), Variable.withString(_kind(kind)),
          Variable.withString(id),
        ]).getSingleOrNull();
        if (current == null ||
            current.read<int>('local_version') != expectedVersion ||
            (current.read<int>('is_deleted') == 1) != restore) {
          throw StateError('Stale or inappropriate delete/restore request.');
        }
        if (restore) {
          final deletedMs = current.readNullable<int>('deleted_at_ms');
          if (deletedMs == null) throw StateError('Missing deletion date.');
          final elapsed = now().toUtc().difference(
            DateTime.fromMillisecondsSinceEpoch(deletedMs, isUtc: true));
          if (elapsed.isNegative || elapsed > recyclePeriod) {
            throw StateError('30-day recovery window has expired.');
          }
          // Approved UX: restoring a goal resets its current savings to 0;
          // restoring a category resets its budget to 0. Ledger history is
          // never changed by either operation.
          await db.customStatement('''
UPDATE working_recoverables SET is_deleted=0,deleted_at_ms=NULL,
 allocated_minor=0,local_version=?
WHERE vault_id=? AND record_kind=? AND record_id=? AND local_version=?
''', [expectedVersion + 1, vaultId, _kind(kind), id, expectedVersion]);
        } else {
          await db.customStatement('''
UPDATE working_recoverables SET is_deleted=1,deleted_at_ms=?,
 local_version=?
WHERE vault_id=? AND record_kind=? AND record_id=? AND local_version=?
''', [
            now().toUtc().millisecondsSinceEpoch, expectedVersion + 1,
            vaultId, _kind(kind), id, expectedVersion,
          ]);
        }
      });
    });
  }
}

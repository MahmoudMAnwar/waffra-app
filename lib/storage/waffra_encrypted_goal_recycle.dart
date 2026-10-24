import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

class WaffraDeletedGoalRecord {
  const WaffraDeletedGoalRecord({
    required this.id,
    required this.name,
    required this.deletedAtMs,
    required this.expiresAtMs,
    required this.linkedTransactions,
  });

  final String id;
  final String name;
  final int deletedAtMs;
  final int expiresAtMs;
  final int linkedTransactions;
}

class WaffraGoalRemovalResult {
  const WaffraGoalRemovalResult({required this.linkedTransactions});
  final int linkedTransactions;
}

/// Isolated encrypted recycle bin for saving goals. NOT connected to UI.
///
/// Deleting a goal must never delete or edit financial transaction history.
/// Restoring retains the same goal ID but deliberately resets saved funds to
/// ZERO, per Waffra's approved goal-recovery behavior.
class WaffraEncryptedGoalRecycle {
  const WaffraEncryptedGoalRecycle({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static const retention = Duration(days: 30);
  static const _table = 'fresh_finance_goal_trash';

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted goal recycle bin is disabled by default.');
    }
    final version = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (version.length != 1 ||
        version.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Fresh finance schema is not initialized.');
    }
    final staged = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (staged.read<int>('n') != 0) {
      throw StateError('Cannot recycle a goal in a legacy migration sandbox.');
    }
  }

  Future<void> _ensureTrashTable() async {
    await store.customStatement('''
CREATE TABLE IF NOT EXISTS $_table (
  goal_id TEXT PRIMARY KEY NOT NULL,
  original_goal_json TEXT NOT NULL,
  name TEXT NOT NULL,
  target_minor INTEGER NOT NULL CHECK(target_minor > 0),
  deleted_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  linked_count_at_deletion INTEGER NOT NULL CHECK(linked_count_at_deletion >= 0)
)''');
  }

  /// Best-effort matching for known explicit goal references. Do not assume
  /// other/new goal-link formats have been identified without a schema audit.
  static bool _linksGoal(Object? payload, String goalId) {
    if (payload is List) {
      return payload.any((value) => _linksGoal(value, goalId));
    }
    if (payload is! Map) return false;
    for (final entry in payload.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (const {
        'goalId', 'goal_id', 'savingGoalId', 'linkedGoalId',
        'goalIds', 'linkedGoals',
      }.contains(key)) {
        if (value == goalId ||
            (value is List && value.contains(goalId))) {
          return true;
        }
      }
      if ((value is Map || value is List) &&
          _linksGoal(value, goalId)) {
        return true;
      }
    }
    return false;
  }

  Future<int> _linkedCount(String goalId) async {
    final rows = await store.customSelect(
      'SELECT source_json FROM fresh_finance_entries',
    ).get();
    var count = 0;
    for (final row in rows) {
      Object? decoded;
      try {
        decoded = jsonDecode(row.read<String>('source_json'));
      } catch (_) {
        throw StateError('Corrupt transaction blocks goal deletion.');
      }
      if (_linksGoal(decoded, goalId)) count++;
    }
    return count;
  }

  /// When a recognized transaction link exists, require explicit approval.
  /// Existing transaction records are never modified or deleted.
  Future<WaffraGoalRemovalResult> deleteGoal(
    String goalId, {
    required DateTime now,
    bool acknowledgeLinkedTransactions = false,
  }) async {
    if (goalId.trim().isEmpty) throw ArgumentError.value(goalId, 'goalId');
    return store.transaction(() async {
      await _requireReady();
      await _ensureTrashTable();
      final old = await store.customSelect(
        'SELECT name,target_minor,source_json FROM fresh_finance_goals '
        'WHERE goal_id=?',
        variables: [Variable.withString(goalId)],
      ).get();
      if (old.length != 1) throw StateError('Goal is missing.');
      final related = await _linkedCount(goalId);
      if (related > 0 && !acknowledgeLinkedTransactions) {
        throw StateError('Linked transactions: deletion requires confirmation.');
      }
      final deletedAt = now.toUtc().millisecondsSinceEpoch;
      final expiresAt = deletedAt + retention.inMilliseconds;
      await store.customStatement(
        'INSERT INTO $_table(goal_id,original_goal_json,name,target_minor,'
        'deleted_at_ms,expires_at_ms,linked_count_at_deletion) '
        'VALUES(?,?,?,?,?,?,?)',
        [
          goalId, old.single.read<String>('source_json'),
          old.single.read<String>('name'),
          old.single.read<int>('target_minor'),
          deletedAt, expiresAt, related,
        ],
      );
      await store.customStatement(
        'DELETE FROM fresh_finance_goals WHERE goal_id=?', [goalId],
      );
      return WaffraGoalRemovalResult(linkedTransactions: related);
    });
  }

  Future<List<WaffraDeletedGoalRecord>> listRecoverable(DateTime now) async {
    await _requireReady();
    final tables = await store.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='$_table'",
    ).get();
    if (tables.isEmpty) return [];
    final rows = await store.customSelect(
      'SELECT goal_id,name,deleted_at_ms,expires_at_ms,'
      'linked_count_at_deletion FROM $_table WHERE expires_at_ms > ? '
      'ORDER BY deleted_at_ms DESC',
      variables: [Variable.withInt(now.toUtc().millisecondsSinceEpoch)],
    ).get();
    return List.unmodifiable(rows.map((row) => WaffraDeletedGoalRecord(
      id: row.read<String>('goal_id'),
      name: row.read<String>('name'),
      deletedAtMs: row.read<int>('deleted_at_ms'),
      expiresAtMs: row.read<int>('expires_at_ms'),
      linkedTransactions: row.read<int>('linked_count_at_deletion'),
    )));
  }

  /// Restores an old goal with *zero* saved money while preserving transaction
  /// history, target, identity and other goal metadata.
  Future<void> restore(String goalId, {required DateTime now}) async {
    return store.transaction(() async {
      await _requireReady();
      await _ensureTrashTable();
      final rows = await store.customSelect(
        'SELECT name,target_minor,original_goal_json,expires_at_ms FROM '
        '$_table WHERE goal_id=?',
        variables: [Variable.withString(goalId)],
      ).get();
      if (rows.length != 1) throw StateError('Goal is not in recycle bin.');
      final row = rows.single;
      if (now.toUtc().millisecondsSinceEpoch >=
          row.read<int>('expires_at_ms')) {
        throw StateError('The 30-day recovery window has expired.');
      }
      final original = jsonDecode(row.read<String>('original_goal_json'));
      if (original is! Map) throw StateError('Stored goal is invalid.');
      final restored = Map<String, Object?>.from(original);
      if (restored['id'] != goalId) {
        throw StateError('Archived goal identity mismatch.');
      }
      restored['saved'] = 0;
      await store.customStatement(
        'INSERT INTO fresh_finance_goals '
        '(goal_id,name,target_minor,saved_minor,source_json) '
        'VALUES(?,?,?,?,?)',
        [
          goalId, row.read<String>('name'),
          row.read<int>('target_minor'), 0, jsonEncode(restored),
        ],
      );
      await store.customStatement(
        'DELETE FROM $_table WHERE goal_id=?', [goalId],
      );
    });
  }

  /// Only call after explicitly approving real deletion of expired trash.
  /// No historical transaction is modified.
  Future<int> purgeExpired(DateTime now, {bool allowPurge = false}) async {
    if (!allowPurge) {
      throw StateError('Permanent goal deletion must be explicitly enabled.');
    }
    return store.transaction(() async {
      await _requireReady();
      await _ensureTrashTable();
      final expired = await store.customSelect(
        'SELECT count(*) AS n FROM $_table WHERE expires_at_ms <= ?',
        variables: [Variable.withInt(now.toUtc().millisecondsSinceEpoch)],
      ).getSingle();
      await store.customStatement(
        'DELETE FROM $_table WHERE expires_at_ms <= ?',
        [now.toUtc().millisecondsSinceEpoch],
      );
      return expired.read<int>('n');
    });
  }
}

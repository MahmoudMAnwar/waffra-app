import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_module_projection_guard.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_fresh_finance_modules_repository.dart';

class WaffraEncryptedModuleRecycleResult {
  const WaffraEncryptedModuleRecycleResult({
    required this.module,
    required this.entityId,
    required this.restored,
    required this.generation,
    required this.expiresAtMs,
  });

  final WaffraFinanceModule module;
  final String entityId;
  final bool restored;
  final int generation;
  final int expiresAtMs;
}

/// Synthetic encrypted *entity-level* retention adapter for categories, goals
/// and recurring schedules. It cannot initialize the production source, read
/// OS keys, or authorize an automatic cutover. Default-off by design.
///
/// Every deletion/restoration updates the canonical active and legacy-shaped
/// trash lists, the typed SQL table, and an independently hashed encrypted
/// tombstone in ONE SQLCipher transaction under the Home/Widget native lock.
/// Transaction history and receipt bytes are never modified.
class WaffraEncryptedModuleRecycle {
  const WaffraEncryptedModuleRecycle({
    required this.snapshot,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  static const retention = Duration(days: 30);
  static const _table = 'fresh_finance_module_recycle';

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  final bool experimentalEnabled;

  String _activeKey(WaffraFinanceModule module) => switch (module) {
        WaffraFinanceModule.categories => 'waffra_categories_v24',
        WaffraFinanceModule.goals => 'waffra_goals_v24',
        WaffraFinanceModule.recurring => 'waffra_recurring_v24',
      };

  String _trashKey(WaffraFinanceModule module) => switch (module) {
        WaffraFinanceModule.categories => 'waffra_deleted_categories_v1',
        WaffraFinanceModule.goals => 'waffra_deleted_goals_v1',
        WaffraFinanceModule.recurring => 'waffra_deleted_recurring_v1',
      };

  String _payloadKey(WaffraFinanceModule module) => switch (module) {
        WaffraFinanceModule.categories => 'category',
        WaffraFinanceModule.goals => 'goal',
        WaffraFinanceModule.recurring => 'recurring',
      };

  String _tableName(WaffraFinanceModule module) => switch (module) {
        WaffraFinanceModule.categories => 'fresh_finance_categories',
        WaffraFinanceModule.goals => 'fresh_finance_goals',
        WaffraFinanceModule.recurring => 'fresh_finance_recurring',
      };

  String _idColumn(WaffraFinanceModule module) => switch (module) {
        WaffraFinanceModule.categories => 'category_id',
        WaffraFinanceModule.goals => 'goal_id',
        WaffraFinanceModule.recurring => 'recurring_id',
      };

  void _requireCandidate() {
    if (!experimentalEnabled || !snapshot.experimentalEnabled) {
      throw StateError('Encrypted module recycle is disabled.');
    }
  }

  Future<void> _ensureTable() async {
    await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS $_table(
  module_name TEXT NOT NULL CHECK(module_name IN ('categories','goals','recurring')),
  entity_id TEXT NOT NULL,
  source_json TEXT NOT NULL,
  source_sha256 TEXT NOT NULL,
  original_index INTEGER NOT NULL CHECK(original_index >= 0),
  deleted_at_ms INTEGER NOT NULL CHECK(deleted_at_ms >= 0),
  expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms > deleted_at_ms),
  PRIMARY KEY(module_name,entity_id)
)''');
  }

  static List<Map<String, Object?>> _decodeList(Object? value) {
    if (value == null) return <Map<String, Object?>>[];
    if (value is! String) {
      throw StateError('Encrypted finance module list is not JSON.');
    }
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw StateError('Encrypted finance module list is not an array.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Encrypted finance module contains an invalid item.');
      }
      return Map<String, Object?>.from(item);
    }).toList(growable: true);
  }

  static String _hash(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();

  static void _requireUniqueEntities(
    List<Map<String, Object?>> entities,
  ) {
    final seen = <String>{};
    for (final row in entities) {
      final id = row['id'];
      if (id is! String || id.trim().isEmpty || id.length > 256 ||
          !seen.add(id)) {
        throw StateError('Encrypted module has ambiguous identities.');
      }
    }
  }

  Future<List<Map<String, Object?>>> _requireAlignedTrash({
    required WaffraFinanceModule module,
    required Map<String, Object?> values,
  }) async {
    await _ensureTable();
    final trash = _decodeList(values[_trashKey(module)]);
    final payload = _payloadKey(module);
    final seen = <String>{};
    final sorted = <String, Map<String, Object?>>{};
    for (final wrapper in trash) {
      final item = wrapper[payload];
      final when = wrapper['deletedAt'];
      if (item is! Map || when is! String) {
        throw StateError('Encrypted module trash is malformed.');
      }
      final actual = Map<String, Object?>.from(item);
      final id = actual['id'];
      final time = DateTime.tryParse(when);
      if (id is! String || id.isEmpty || !seen.add(id) ||
          time == null || time.toUtc().millisecondsSinceEpoch < 0) {
        throw StateError('Encrypted module trash identities are invalid.');
      }
      sorted[id] = wrapper;
    }
    final sql = await snapshot.store.customSelect(
      'SELECT entity_id,source_json,source_sha256,original_index,'
      'deleted_at_ms,expires_at_ms FROM $_table WHERE module_name=?',
      variables: [Variable.withString(module.name)],
    ).get();
    if (sql.length != trash.length) {
      throw StateError('Encrypted module trash and SQL witness differ.');
    }
    for (final row in sql) {
      final id = row.read<String>('entity_id');
      final wrapper = sorted[id];
      if (wrapper == null) {
        throw StateError('Encrypted module trash has an orphan SQL tombstone.');
      }
      final saved = row.read<String>('source_json');
      final source = jsonEncode(wrapper[payload]);
      final stamp = DateTime.parse(wrapper['deletedAt'] as String)
          .toUtc().millisecondsSinceEpoch;
      if (saved != source ||
          _hash(saved) != row.read<String>('source_sha256') ||
          row.read<int>('original_index') < 0 ||
          row.read<int>('deleted_at_ms') != stamp ||
          row.read<int>('expires_at_ms') - stamp != retention.inMilliseconds) {
        throw StateError('Encrypted module trash checksum or clock differs.');
      }
    }
    return trash;
  }

  Future<void> _verifyActive({
    required WaffraFinanceModule module,
    required Map<String, Object?> values,
  }) async {
    final raw = values[_activeKey(module)];
    if (raw != null && raw is! String) {
      throw StateError('Encrypted module source type is invalid.');
    }
    await WaffraEncryptedModuleProjectionGuard.reconcile(
      store: snapshot.store,
      key: _activeKey(module),
      previousJson: raw as String?,
      updatedJson: raw,
    );
  }

  Future<WaffraFinanceSnapshotState> _currentWithWitness(
    WaffraFinanceSnapshotState baseline,
  ) async {
    final current = await snapshot.read();
    if (current.generation != baseline.generation ||
        current.digest != baseline.digest) {
      throw StateError('Encrypted module changed after user confirmation.');
    }
    return current;
  }

  /// Archive one entity and remove only its active typed row. A category
  /// parent with live children is blocked. A recurring schedule with pending
  /// postponements is blocked until its linked state is resolved explicitly.
  Future<WaffraEncryptedModuleRecycleResult> softDelete({
    required WaffraFinanceModule module,
    required WaffraFinanceSnapshotState baseline,
    required String entityId,
    required DateTime now,
    required bool userConfirmed,
  }) async {
    _requireCandidate();
    if (!userConfirmed || entityId.trim().isEmpty || entityId.length > 256) {
      throw StateError('A confirmed, exact finance entity is required.');
    }
    final at = now.toUtc().millisecondsSinceEpoch;
    if (at < 0 || at > 8640000000000000 - retention.inMilliseconds) {
      throw ArgumentError('Invalid delete time.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final current = await _currentWithWitness(baseline);
        await _verifyActive(module: module, values: current.values);
        final active = _decodeList(current.values[_activeKey(module)]);
        _requireUniqueEntities(active);
        final trash = await _requireAlignedTrash(
          module: module, values: current.values,
        );
        final position = active.indexWhere((x) => x['id'] == entityId);
        if (position < 0 || trash.any(
            (x) => (x[_payloadKey(module)] as Map)['id'] == entityId)) {
          throw StateError('Encrypted entity is missing or already recycled.');
        }
        final record = active[position];
        if (module == WaffraFinanceModule.categories &&
            active.any((x) => x['parentId'] == entityId)) {
          throw StateError('Delete child categories before their parent.');
        }
        if (module == WaffraFinanceModule.recurring) {
          final postponed = jsonDecode(
            (current.values['waffra_recurring_postponed_v1'] as String?) ?? '{}',
          );
          if (postponed is! Map || postponed.isNotEmpty) {
            throw StateError('Resolve pending recurring postings before deletion.');
          }
        }
        final until = at + retention.inMilliseconds;
        final recordJson = jsonEncode(record);
        await snapshot.store.customStatement(
          'INSERT INTO $_table(module_name,entity_id,source_json,'
          'source_sha256,original_index,deleted_at_ms,expires_at_ms) '
          'VALUES (?,?,?,?,?,?,?)',
          [module.name, entityId, recordJson, _hash(recordJson),
           position, at, until],
        );
        await snapshot.store.customStatement(
          'DELETE FROM ${_tableName(module)} '
          'WHERE ${_idColumn(module)}=?', [entityId],
        );
        active.removeAt(position);
        trash.add(<String, Object?>{
          _payloadKey(module): record,
          'deletedAt': now.toUtc().toIso8601String(),
        });
        final next = Map<String, Object?>.from(current.values)
          ..[_activeKey(module)] = jsonEncode(active)
          ..[_trashKey(module)] = jsonEncode(trash);
        if (!WaffraLegacyPreflight.inspect(next).canStage) {
          throw StateError('Encrypted module recycle failed preflight.');
        }
        final saved = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
        await _verifyActive(module: module, values: saved.values);
        await _requireAlignedTrash(module: module, values: saved.values);
        return WaffraEncryptedModuleRecycleResult(
          module: module,
          entityId: entityId,
          restored: false,
          generation: saved.generation,
          expiresAtMs: until,
        );
      });
    });
  }

  Future<WaffraEncryptedModuleRecycleResult> restore({
    required WaffraFinanceModule module,
    required WaffraFinanceSnapshotState baseline,
    required String entityId,
    required DateTime now,
  }) async {
    _requireCandidate();
    if (entityId.trim().isEmpty || entityId.length > 256) {
      throw ArgumentError('Invalid finance entity identity.');
    }
    final at = now.toUtc().millisecondsSinceEpoch;
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final current = await _currentWithWitness(baseline);
        await _verifyActive(module: module, values: current.values);
        final active = _decodeList(current.values[_activeKey(module)]);
        _requireUniqueEntities(active);
        final trash = await _requireAlignedTrash(
          module: module, values: current.values,
        );
        final payload = _payloadKey(module);
        final index = trash.indexWhere(
          (x) => (x[payload] as Map)['id'] == entityId,
        );
        if (index < 0 || active.any((x) => x['id'] == entityId)) {
          throw StateError('Entity is not uniquely recoverable.');
        }
        final archived = await snapshot.store.customSelect(
          'SELECT source_json,source_sha256,original_index,deleted_at_ms,'
          'expires_at_ms FROM $_table WHERE module_name=? AND entity_id=?',
          variables: [Variable.withString(module.name),
                      Variable.withString(entityId)],
        ).get();
        if (archived.length != 1) {
          throw StateError('Missing encrypted module restore witness.');
        }
        final row = archived.single;
        final deletedAt = row.read<int>('deleted_at_ms');
        final expiry = row.read<int>('expires_at_ms');
        if (at < deletedAt || at >= expiry ||
            expiry - deletedAt != retention.inMilliseconds) {
          throw StateError('Encrypted module recovery expired or clock rolled back.');
        }
        final encoded = row.read<String>('source_json');
        if (_hash(encoded) != row.read<String>('source_sha256')) {
          throw StateError('Archived financial module checksum differs.');
        }
        final decoded = jsonDecode(encoded);
        if (decoded is! Map<String, dynamic> || decoded['id'] != entityId) {
          throw StateError('Archived finance entity is invalid.');
        }
        final entity = Map<String, Object?>.from(decoded);
        if (module == WaffraFinanceModule.categories) {
          final parent = entity['parentId'];
          if (parent is String && parent.isNotEmpty &&
              !active.any((x) => x['id'] == parent)) {
            throw StateError('Restore the deleted parent category first.');
          }
          entity['budget'] = 0.0;
        }
        if (module == WaffraFinanceModule.goals) {
          entity['saved'] = 0.0;
        }
        if (module == WaffraFinanceModule.recurring) {
          // Undo must NEVER trigger overdue posting or re-enable a schedule.
          // A user must explicitly choose a new due date and activate later.
          entity['active'] = false;
        }
        final repo = WaffraFreshModulesRepository(
          store: snapshot.store, experimentalEnabled: true,
        );
        await repo.save(module, entity);
        final original = row.read<int>('original_index');
        final atIndex = original > active.length ? active.length : original;
        active.insert(atIndex, entity);
        trash.removeAt(index);
        await snapshot.store.customStatement(
          'DELETE FROM $_table WHERE module_name=? AND entity_id=?',
          [module.name, entityId],
        );
        final next = Map<String, Object?>.from(current.values)
          ..[_activeKey(module)] = jsonEncode(active)
          ..[_trashKey(module)] = jsonEncode(trash);
        if (!WaffraLegacyPreflight.inspect(next).canStage) {
          throw StateError('Encrypted restored module failed preflight.');
        }
        final saved = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
        await _verifyActive(module: module, values: saved.values);
        await _requireAlignedTrash(module: module, values: saved.values);
        return WaffraEncryptedModuleRecycleResult(
          module: module,
          entityId: entityId,
          restored: true,
          generation: saved.generation,
          expiresAtMs: expiry,
        );
      });
    });
  }

  /// No automatic expiry purge: a trusted retention clock and device restore
  /// attestor have not yet been approved for a live encrypted finance source.
  Future<Map<String, int>> pending(WaffraFinanceModule module) async {
    _requireCandidate();
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      final current = await snapshot.read();
      await _verifyActive(module: module, values: current.values);
      await _requireAlignedTrash(module: module, values: current.values);
      final rows = await snapshot.store.customSelect(
        'SELECT entity_id,expires_at_ms FROM $_table WHERE module_name=?',
        variables: [Variable.withString(module.name)],
      ).get();
      return Map<String, int>.unmodifiable({
        for (final row in rows)
          row.read<String>('entity_id'): row.read<int>('expires_at_ms'),
      });
    });
  }
}

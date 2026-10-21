import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

class WaffraFinanceSnapshotState {
  const WaffraFinanceSnapshotState({
    required this.generation,
    required this.digest,
    required this.values,
  });

  final int generation;
  final String digest;
  /// Fully preserved finance preferences, with absent keys still absent.
  final Map<String, Object?> values;
}

/// A test-only, all-finance-fields transition store.
///
/// One encrypted SQL transaction persists the *entire* finance snapshot AND
/// its monotonically increasing revision, unlike the current non-atomic
/// SharedPreferences loop in HomeScreen.persist().
///
/// Neither the running dashboard nor Android widget uses this yet. A
/// participating single-writer gate, verified source selector, old-data
/// migration and recovery must be implemented before live activation.
class WaffraAtomicFinanceSnapshot {
  const WaffraAtomicFinanceSnapshot({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static const _table = 'fresh_finance_snapshot_state';

  static Map<String, Object?> _validate(Map<String, Object?> input) {
    final extra = input.keys.toSet().difference(
      WaffraLegacyPreflight.allKeys.toSet(),
    );
    if (extra.isNotEmpty) {
      throw ArgumentError('Finance snapshot contains unknown keys.');
    }
    final result = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys) {
      if (!input.containsKey(key)) continue;
      final value = input[key];
      if (WaffraLegacyPreflight.financeListOfStringsKeys.contains(key)) {
        if (value is! List<String>) {
          throw ArgumentError('SMS deduplication hashes must be string values.');
        }
        result[key] = List<String>.unmodifiable(value);
      } else if (value is String || value is bool || value is num) {
        result[key] = value;
      } else {
        throw ArgumentError('Unsupported finance key value.');
      }
    }
    final preflight = WaffraLegacyPreflight.inspect(result);
    if (!preflight.canStage) {
      throw StateError('Finance snapshot failed preflight verification.');
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  static String _jsonOf(Map<String, Object?> snapshot) {
    final sorted = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys.toList()..sort()) {
      if (snapshot.containsKey(key)) sorted[key] = snapshot[key];
    }
    return jsonEncode(sorted);
  }

  static String _digest(String json) =>
      sha256.convert(utf8.encode(json)).toString();

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Atomic finance snapshot is disabled by default.');
    }
    final version = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (version.length != 1 ||
        version.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Fresh encrypted vault is unavailable or incompatible.');
    }
    final staged = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (staged.read<int>('n') != 0) {
      throw StateError('Refusing to overwrite a staged legacy vault.');
    }
  }

  /// Idempotent, non-destructive initialization of a truly fresh vault.
  /// No default categories or artificial transactions are manufactured.
  Future<WaffraFinanceSnapshotState> initializeEmpty() async {
    return store.transaction(() async {
      await _requireReady();
      await store.customStatement('''
CREATE TABLE IF NOT EXISTS $_table(
  singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
  generation INTEGER NOT NULL CHECK(generation>=0),
  digest TEXT NOT NULL,
  snapshot_json TEXT NOT NULL
)''');
      final existing = await store.customSelect(
        'SELECT generation,digest,snapshot_json FROM $_table '
        'WHERE singleton=1',
      ).get();
      if (existing.isEmpty) {
        final json = _jsonOf(const {});
        await store.customStatement(
          'INSERT INTO $_table(singleton,generation,digest,snapshot_json) '
          'VALUES (1,0,?,?)',
          [_digest(json), json],
        );
      }
      return _readUnsafe();
    });
  }

  Future<WaffraFinanceSnapshotState> read() async {
    await _requireReady();
    return _readUnsafe();
  }

  Future<WaffraFinanceSnapshotState> _readUnsafe() async {
    final rows = await store.customSelect(
      'SELECT generation,digest,snapshot_json FROM $_table '
      'WHERE singleton=1',
    ).get();
    if (rows.length != 1) {
      throw StateError('Finance snapshot has not been initialized.');
    }
    final row = rows.single;
    final raw = row.read<String>('snapshot_json');
    final digest = row.read<String>('digest');
    if (_digest(raw) != digest) {
      throw StateError('Encrypted financial snapshot checksum mismatch.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Finance snapshot is not a JSON object.');
    }
    final normalized = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (WaffraLegacyPreflight.financeListOfStringsKeys.contains(entry.key)) {
        final value = entry.value;
        if (value is! List || value.any((x) => x is! String)) {
          throw StateError('Finance SMS hashes have invalid encoding.');
        }
        normalized[entry.key] = List<String>.unmodifiable(
          value.cast<String>(),
        );
      } else {
        normalized[entry.key] = entry.value;
      }
    }
    final valid = _validate(normalized);
    if (_jsonOf(valid) != raw) {
      throw StateError('Finance snapshot encoding is not canonical.');
    }
    return WaffraFinanceSnapshotState(
      generation: row.read<int>('generation'),
      digest: digest,
      values: valid,
    );
  }

  /// Caller must hold the same writer gate as the dashboard/Android widget.
  /// Stale snapshots fail: never overwrite a later save with old UI state.
  Future<WaffraFinanceSnapshotState> commit({
    required int expectedGeneration,
    required Map<String, Object?> fullFinanceSnapshot,
  }) async {
    if (expectedGeneration < 0 ||
        expectedGeneration >= 9223372036854775806) {
      throw ArgumentError.value(expectedGeneration, 'expectedGeneration');
    }
    final captured = _validate(fullFinanceSnapshot);
    final json = _jsonOf(captured);
    final digest = _digest(json);
    return store.transaction(() async {
      await _requireReady();
      final before = await _readUnsafe();
      if (before.generation != expectedGeneration) {
        throw StateError('Stale finance snapshot: reload before saving.');
      }
      await store.customStatement(
        'UPDATE $_table SET generation=?,digest=?,snapshot_json=? '
        'WHERE singleton=1 AND generation=?',
        [expectedGeneration + 1, digest, json, expectedGeneration],
      );
      final after = await _readUnsafe();
      if (after.generation != expectedGeneration + 1 ||
          after.digest != digest) {
        throw StateError('Finance atomic commit parity mismatch.');
      }
      return after;
    });
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'legacy_financial_snapshot.dart';
import 'legacy_snapshot_preflight.dart' as checksum_preflight;

/// An isolated, opt-in technical spike. NOT connected to main.dart, load(),
/// persist(), Firebase, app startup, or any live user migration.
/// This schema is a lossless STAGING AREA, not the final relational schema.
class WaffraEncryptedStore extends GeneratedDatabase {
  WaffraEncryptedStore._(QueryExecutor executor) : super(executor);

  static const _keyStorageName = 'waffra_vault_encryption_key_v1';
  static const _filename = 'waffra_shadow_v1.sqlite';

  /// Only call from an explicitly gated migration after write-freeze has been
  /// implemented. This method intentionally doesn't read SharedPreferences.
  static Future<WaffraEncryptedStore> openShadow({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    String? key = await secureStorage.read(key: _keyStorageName);
    if (key == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final proposed = base64UrlEncode(bytes);
      // On interruption retry, never regenerate over a previously opened DB.
      final existing = File('${directory.path}/$_filename');
      if (await existing.exists()) {
        throw StateError('Encrypted vault exists but its key is unavailable.');
      }
      await secureStorage.write(key: _keyStorageName, value: proposed);
      key = await secureStorage.read(key: _keyStorageName);
      if (key != proposed) {
        throw StateError('Secure-key persistence could not be confirmed.');
      }
    }
    return openAt(File('${directory.path}/$_filename'), key: key!);
  }

  /// Injectable key + file path allow deterministic tests without mobile APIs.
  /// This is not a production key source. Never hard-code a real user key.
  static WaffraEncryptedStore openAt(File file, {required String key}) {
    if (key.length < 24) throw ArgumentError.value(key.length, 'key.length');
    return WaffraEncryptedStore._(NativeDatabase(
      file,
      logStatements: false,
      setup: (db) {
        // Fail closed in EVERY build, not only debug/assert.
        // Ordinary SQLite ignores this pragma and returns no result.
        final supportedCipher = db.select('PRAGMA cipher');
        if (supportedCipher.isEmpty) {
          throw StateError('Encrypted SQLite engine is unavailable.');
        }
        final escaped = key.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped'");
        db.execute('PRAGMA foreign_keys = ON');
        // Forces a real read, thus immediately detecting an incorrect key.
        db.select('SELECT count(*) FROM sqlite_master');
      },
    ));
  }

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allSchemaEntities => const [];

  @override
  List<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) async {
        await customStatement('''
CREATE TABLE IF NOT EXISTS shadow_vaults (
  vault_id TEXT PRIMARY KEY NOT NULL,
  created_at_ms INTEGER NOT NULL
)''');
        await customStatement('''
CREATE TABLE IF NOT EXISTS shadow_records (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  source_key TEXT NOT NULL,
  source_index INTEGER NOT NULL,
  source_value_json TEXT NOT NULL,
  PRIMARY KEY (vault_id, source_key, source_index)
)''');
        await customStatement('''
CREATE TABLE IF NOT EXISTS shadow_migrations (
  vault_id TEXT NOT NULL REFERENCES shadow_vaults(vault_id),
  source_sha256 TEXT NOT NULL,
  source_count INTEGER NOT NULL,
  income_minor INTEGER NOT NULL,
  expense_minor INTEGER NOT NULL,
  receipt_references INTEGER NOT NULL,
  completed_at_ms INTEGER NOT NULL,
  PRIMARY KEY (vault_id, source_sha256)
)''');
      });

  /// Stores a *copy* of legacy financial records, including full JSON snapshots.
  /// All inserts and the migration journal are in the SAME SQLite transaction.
  /// Any invalid finance data blocks staging and preserves the original source.
  Future<ShadowImportReport> stageSnapshot(
    String vaultId,
    Map<String, Object?> snapshot,
  ) async {
    if (vaultId.trim().isEmpty) throw ArgumentError('vaultId cannot be empty');
    final preflight = const WaffraLegacySnapshotInspector().inspect(snapshot);
    final checksum = checksum_preflight.WaffraLegacyPreflight.inspect(snapshot);
    if (!preflight.canStage || !checksum.canStage) {
      throw StateError('Legacy preflight failed. Original data was untouched.');
    }

    // Avoid ever claiming these checks include receipt files themselves.
    final sourceRows = <(String, int, String)>[];
    final keys = checksum_preflight.WaffraLegacyPreflight.allKeys.toList()..sort();
    for (final key in keys) {
      if (!snapshot.containsKey(key)) continue;
      final raw = snapshot[key];
      if (checksum_preflight.WaffraLegacyPreflight.financeListKeys.contains(key)) {
        final items = jsonDecode(raw as String) as List<dynamic>;
        for (var i = 0; i < items.length; i++) {
          sourceRows.add((key, i, jsonEncode(items[i])));
        }
      } else if (checksum_preflight.WaffraLegacyPreflight.financeMapKeys.contains(key)) {
        final entries = (jsonDecode(raw as String) as Map<String, dynamic>).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (var i = 0; i < entries.length; i++) {
          sourceRows.add((key, i, jsonEncode({'key': entries[i].key, 'value': entries[i].value})));
        }
      } else if (checksum_preflight.WaffraLegacyPreflight.financeListOfStringsKeys.contains(key)) {
        final items = raw as List<String>;
        for (var i = 0; i < items.length; i++) {
          sourceRows.add((key, i, jsonEncode(items[i])));
        }
      } else {
        sourceRows.add((key, 0, jsonEncode(raw)));
      }
    }

    final digest = checksum.sourceSha256;
    await transaction(() async {
      await customStatement(
        'INSERT OR IGNORE INTO shadow_vaults(vault_id,created_at_ms) VALUES (?,?)',
        [vaultId, DateTime.now().millisecondsSinceEpoch],
      );
      final otherMigrations = await customSelect(
        'SELECT source_sha256 FROM shadow_migrations WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).get();
      if (otherMigrations.any((r) => r.read<String>('source_sha256') != digest)) {
        throw StateError('Vault already contains a different source snapshot.');
      }
      final already = otherMigrations.isNotEmpty;
      if (!already) {
        for (final row in sourceRows) {
          await customStatement(
            'INSERT INTO shadow_records(vault_id,source_key,source_index,source_value_json) '
            'VALUES (?,?,?,?)',
            [vaultId, row.$1, row.$2, row.$3],
          );
        }
        await customStatement('''
INSERT INTO shadow_migrations(vault_id,source_sha256,source_count,income_minor,
expense_minor,receipt_references,completed_at_ms) VALUES (?,?,?,?,?,?,?)
''', [
          vaultId, digest, sourceRows.length, preflight.incomeMinor,
          preflight.expenseMinor, preflight.receiptReferences,
          DateTime.now().millisecondsSinceEpoch,
        ]);
      }
      final actual = await customSelect(
        'SELECT count(*) AS total FROM shadow_records WHERE vault_id = ?',
        variables: [Variable.withString(vaultId)],
      ).getSingle();
      if (actual.read<int>('total') != sourceRows.length) {
        throw StateError('Shadow import parity check failed.');
      }
    });

    return ShadowImportReport(
      sourceSha256: digest,
      recordCount: sourceRows.length,
      incomeMinor: preflight.incomeMinor,
      expenseMinor: preflight.expenseMinor,
      receiptReferences: preflight.receiptReferences,
    );
  }

  Future<int> stagedRowCount(String vaultId) async {
    final row = await customSelect(
      'SELECT count(*) AS total FROM shadow_records WHERE vault_id = ?',
      variables: [Variable.withString(vaultId)],
    ).getSingle();
    return row.read<int>('total');
  }
}

class ShadowImportReport {
  const ShadowImportReport({
    required this.sourceSha256,
    required this.recordCount,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.receiptReferences,
  });
  final String sourceSha256;
  final int recordCount;
  final int incomeMinor;
  final int expenseMinor;
  final int receiptReferences;
}

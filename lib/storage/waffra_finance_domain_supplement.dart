import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../waffra_secure_backup.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// Authenticated, portable *supplement* for the 13 relational domain tables.
/// The main ledger, categories/goals/recurring, receipts and snapshot MUST be
/// backed up independently through the base finance archive. This object is
/// not a standalone full .waffra backup and cannot activate a production source.
///
/// Both export and restore require the caller to own an encrypted SQLCipher
/// connection under the finance-wide Home/Widget writer lock.
class WaffraFinanceDomainSupplement {
  const WaffraFinanceDomainSupplement({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static const maxRows = 100000;
  static const maxClearCharacters = 24 * 1024 * 1024;
  static const maxEncryptedCharacters = 35 * 1024 * 1024;
  static const _format = 'waffra-sqlcipher-domain-supplement';
  static const _archiveVersion = 1;

  Future<void> _ready() async {
    if (!experimentalEnabled) {
      throw StateError('Finance-domain supplement is not enabled.');
    }
    await WaffraFreshFinanceDomainSchema.requireReady(store);
  }

  static String _digest(Map<String, Object?> data) =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();

  Future<List<String>> _columns(String table) async {
    // table is selected exclusively from the audited constant whitelist.
    if (!WaffraFreshFinanceDomainSchema.domainTables.contains(table)) {
      throw StateError('Unapproved SQLCipher table.');
    }
    final info = await store.customSelect('PRAGMA table_info(' + table + ')').get();
    if (info.isEmpty) {
      throw StateError('Missing SQLCipher finance-domain table.');
    }
    final columns = <String>[];
    for (final row in info) {
      final name = row.read<String>('name');
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
        throw StateError('Unexpected finance-domain column name.');
      }
      columns.add(name);
    }
    if (columns.toSet().length != columns.length) {
      throw StateError('Duplicate SQLCipher columns.');
    }
    return columns;
  }

  Future<String> export({
    required String password,
    required bool explicitlyApproved,
  }) async {
    await _ready();
    if (!explicitlyApproved) {
      throw StateError('User approval is required to export saved finance.');
    }
    if (!WaffraSecureBackup.isValidNewPassword(password)) {
      throw const FormatException('A strong archive password is required.');
    }

    // Read all domain rows from one SQL snapshot, never per-table at separate
    // write generations. The runtime caller still must take the native lock.
    final tables = await store.transaction(() async {
      final result = <String, Object?>{};
      var total = 0;
      for (final name in WaffraFreshFinanceDomainSchema.domainTables) {
        final columns = await _columns(name);
        final rows = await store.customSelect(
          'SELECT * FROM ' + name,
        ).get();
        total += rows.length;
        if (total > maxRows) {
          throw StateError('Finance-domain backup exceeds row limit.');
        }
        final copied = <Map<String, Object?>>[];
        for (final row in rows) {
          final item = <String, Object?>{};
          for (final column in columns) {
            final value = row.data[column];
            if (value is! String && value is! int &&
                value is! double && value != null) {
              throw StateError('Nonportable SQLCipher column type.');
            }
            item[column] = value;
          }
          copied.add(item);
        }
        result[name] = copied;
      }
      final foreignKeys = await store.customSelect('PRAGMA foreign_key_check').get();
      if (foreignKeys.isNotEmpty) {
        throw StateError('Finance-domain foreign key integrity failed.');
      }
      return result;
    });

    final body = <String, Object?>{
      'format': _format,
      'version': _archiveVersion,
      'domainVersion': WaffraFreshFinanceDomainSchema.version,
      'tables': tables,
    };
    final envelope = jsonEncode({...body, 'sha256': _digest(body)});
    if (envelope.length > maxClearCharacters) {
      throw StateError('Finance-domain backup exceeds capacity.');
    }
    return WaffraSecureBackup.encryptUserBackup(envelope, password);
  }

  /// Restore into a domain-empty, independently verified encrypted finance
  /// vault with matching parent finance entities. No DELETE/UPSERT is used.
  /// Failures roll back all domain tables together, including FK errors.
  Future<void> restore({
    required String encryptedArchive,
    required String password,
    required bool explicitlyApproved,
  }) async {
    await _ready();
    if (!explicitlyApproved) {
      throw StateError('User approval is required to restore saved finance.');
    }
    if (encryptedArchive.length > maxEncryptedCharacters ||
        !WaffraSecureBackup.hasValidEncryptedHeader(encryptedArchive)) {
      throw const FormatException('Invalid encrypted domain supplement.');
    }
    final encryptedHeader = jsonDecode(encryptedArchive);
    if (encryptedHeader is! Map || encryptedHeader['version'] != 2) {
      throw const FormatException('Argon2id authenticated backup is required.');
    }
    final clear = await WaffraSecureBackup.decrypt(encryptedArchive, password);
    if (clear.length > maxClearCharacters) {
      throw const FormatException('Finance-domain supplement is too large.');
    }
    final payload = jsonDecode(clear);
    if (payload is! Map ||
        payload.keys.toSet().difference(
          {'format', 'version', 'domainVersion', 'tables', 'sha256'},
        ).isNotEmpty ||
        payload.length != 5 ||
        payload['format'] != _format ||
        payload['version'] != _archiveVersion ||
        payload['domainVersion'] != WaffraFreshFinanceDomainSchema.version ||
        payload['sha256'] is! String ||
        payload['tables'] is! Map) {
      throw const FormatException('Unrecognized finance-domain supplement.');
    }
    final tables = Map<String, Object?>.from(payload['tables'] as Map);
    final expected = WaffraFreshFinanceDomainSchema.domainTables.toSet();
    if (tables.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(tables.keys.toSet()).isNotEmpty) {
      throw StateError('Finance-domain backup has missing or extra tables.');
    }
    final body = <String, Object?>{
      'format': payload['format'],
      'version': payload['version'],
      'domainVersion': payload['domainVersion'],
      'tables': tables,
    };
    if (_digest(body) != payload['sha256']) {
      throw StateError('Finance-domain backup content checksum mismatch.');
    }

    var total = 0;
    final verified = <String, List<Map<String, Object?>>>{};
    for (final name in WaffraFreshFinanceDomainSchema.domainTables) {
      final raw = tables[name];
      if (raw is! List) throw const FormatException('Invalid table row list.');
      total += raw.length;
      if (total > maxRows) throw StateError('Too many finance-domain rows.');
      final fields = (await _columns(name)).toSet();
      final items = <Map<String, Object?>>[];
      for (final item in raw) {
        if (item is! Map || item.keys.any((key) => key is! String)) {
          throw const FormatException('Invalid finance-domain row.');
        }
        final row = Map<String, Object?>.from(item);
        if (row.keys.toSet().difference(fields).isNotEmpty ||
            fields.difference(row.keys.toSet()).isNotEmpty ||
            row.values.any((v) => v is! String && v is! num && v != null)) {
          throw const FormatException('Finance-domain schema mismatch.');
        }
        items.add(row);
      }
      verified[name] = items;
    }

    await store.transaction(() async {
      // Preserve all existing finance. A repeated restore is never an UPSERT.
      for (final table in WaffraFreshFinanceDomainSchema.domainTables) {
        final count = await store.customSelect(
          'SELECT count(*) AS n FROM ' + table,
        ).getSingle();
        if (count.read<int>('n') != 0) {
          throw StateError('Target domain contains data; restore refused.');
        }
      }
      // The whitelist order places parent tables before dependent child rows.
      for (final table in WaffraFreshFinanceDomainSchema.domainTables) {
        final columns = await _columns(table);
        final placeholders = List<String>.filled(columns.length, '?').join(',');
        final sql = 'INSERT INTO ' + table + ' (' +
          columns.join(',') + ') VALUES (' + placeholders + ')';
        for (final row in verified[table]!) {
          await store.customStatement(
            sql, [for (final column in columns) row[column]],
          );
        }
        final actual = await store.customSelect(
          'SELECT count(*) AS n FROM ' + table,
        ).getSingle();
        if (actual.read<int>('n') != verified[table]!.length) {
          throw StateError('Restored finance-domain row count differs.');
        }
      }
      if ((await store.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
        throw StateError('Restored finance-domain references are invalid.');
      }
    });
  }
}

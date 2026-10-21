import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

class WaffraEncryptedReceipt {
  const WaffraEncryptedReceipt({
    required this.entryId,
    required this.position,
    required this.safeName,
    required this.sha256Hex,
    required this.bytes,
  });

  final String entryId;
  final int position;
  final String safeName;
  final String sha256Hex;
  final Uint8List bytes;
}

/// New-install receipts can be stored *inside* the SQLCipher database.
/// This avoids an unsafe split commit between external image files and SQL.
/// This experimental adapter never touches real receipt files or old paths.
/// Live UI still uses legacy image files until a verified source cutover.
class WaffraEncryptedReceiptVault {
  const WaffraEncryptedReceiptVault({
    required this.store,
    this.experimentalEnabled = false,
  });

  static const maxReceiptBytes = 8 * 1024 * 1024;
  static const maxReceiptsPerEntry = 10;
  static const _table = 'fresh_finance_receipt_blobs';

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt store is disabled by default.');
    }
    final revisions = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (revisions.length != 1 ||
        revisions.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Encrypted finance vault is not initialized.');
    }
    final legacy = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (legacy.read<int>('n') != 0) {
      throw StateError('Legacy migration store cannot receive new receipts.');
    }
  }

  Future<void> _ensureTable() async {
    await store.customStatement('''
CREATE TABLE IF NOT EXISTS $_table(
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_name TEXT NOT NULL UNIQUE,
  content_sha256 TEXT NOT NULL,
  content_bytes INTEGER NOT NULL CHECK(content_bytes > 0),
  encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id,position)
)''');
  }

  static String _safeName(String entryId, int position) {
    final digest = sha256.convert(
      utf8.encode(jsonEncode([entryId, position])),
    ).toString();
    return '$digest.bin';
  }

  /// Attaches all image bytes in ONE SQLCipher transaction. Neither the
  /// entry nor the attachment table can be partially committed on failure.
  /// No filesystem path is stored or written.
  Future<void> attachNewBatch({
    required String entryId,
    required List<Uint8List> images,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt store is disabled by default.');
    }
    if (entryId.trim().isEmpty ||
        images.isEmpty ||
        images.length > maxReceiptsPerEntry ||
        images.any((part) =>
            part.isEmpty || part.length > maxReceiptBytes)) {
      throw ArgumentError('Invalid number or size of receipt images.');
    }
    // Copy bytes before any await; the UI cannot alter the original buffers
    // while the vault computes hashes and commits their payloads.
    final captured = images.map((part) => Uint8List.fromList(part)).toList();
    return store.transaction(() async {
      await _requireReady();
      await _ensureTable();
      final prior = await store.customSelect(
        'SELECT receipt_count FROM fresh_finance_entries WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).get();
      if (prior.length != 1) throw StateError('Transaction does not exist.');
      if (prior.single.read<int>('receipt_count') != 0) {
        throw StateError('Transaction already has receipt attachments.');
      }
      final old = await store.customSelect(
        'SELECT count(*) AS n FROM $_table WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).getSingle();
      if (old.read<int>('n') != 0) {
        throw StateError('Receipt record already exists.');
      }

      for (var position = 0; position < captured.length; position++) {
        final part = captured[position];
        await store.customStatement(
          'INSERT INTO $_table(entry_id,position,safe_name,'
          'content_sha256,content_bytes,encrypted_blob) '
          'VALUES (?,?,?,?,?,?)',
          [
            entryId, position, _safeName(entryId, position),
            sha256.convert(part).toString(), part.length, part,
          ],
        );
      }
      await store.customStatement(
        'UPDATE fresh_finance_entries SET receipt_count=? '
        'WHERE entry_id=?',
        [captured.length, entryId],
      );
      final check = await store.customSelect(
        'SELECT count(*) AS n FROM $_table WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).getSingle();
      if (check.read<int>('n') != captured.length) {
        throw StateError('Receipt count parity check failed.');
      }
    });
  }

  Future<List<WaffraEncryptedReceipt>> readAll(String entryId) async {
    await _requireReady();
    final exists = await store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='$_table'",
    ).get();
    if (exists.isEmpty) return [];
    final row = await store.customSelect(
      'SELECT receipt_count FROM fresh_finance_entries WHERE entry_id=?',
      variables: [Variable.withString(entryId)],
    ).get();
    if (row.length != 1) {
      throw StateError('Transaction does not exist.');
    }
    final count = row.single.read<int>('receipt_count');
    final records = await store.customSelect(
      'SELECT position,safe_name,content_sha256,content_bytes,encrypted_blob '
      'FROM $_table WHERE entry_id=? ORDER BY position',
      variables: [Variable.withString(entryId)],
    ).get();
    if (records.length != count) {
      throw StateError('Transaction receipt count and saved bytes disagree.');
    }
    final decoded = <WaffraEncryptedReceipt>[];
    for (var i = 0; i < records.length; i++) {
      final part = records[i];
      final position = part.read<int>('position');
      final safeName = part.read<String>('safe_name');
      final digest = part.read<String>('content_sha256');
      final bytes = Uint8List.fromList(part.read<Uint8List>('encrypted_blob'));
      if (position != i ||
          safeName != _safeName(entryId, position) ||
          bytes.length != part.read<int>('content_bytes') ||
          digest != sha256.convert(bytes).toString()) {
        throw StateError('Encrypted receipt checksum or position mismatch.');
      }
      decoded.add(WaffraEncryptedReceipt(
        entryId: entryId, position: position,
        safeName: safeName, sha256Hex: digest, bytes: bytes,
      ));
    }
    return List<WaffraEncryptedReceipt>.unmodifiable(decoded);
  }
}

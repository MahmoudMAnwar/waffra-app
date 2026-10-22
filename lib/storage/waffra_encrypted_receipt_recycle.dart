import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

class WaffraReceiptRecycleResult {
  const WaffraReceiptRecycleResult({
    required this.generation,
    required this.receiptCount,
    required this.expiresAtMs,
  });

  final int generation;
  final int receiptCount;
  final int expiresAtMs;
}

/// Candidate SQLCipher-only reversible removal of a COMPLETE receipt batch.
///
/// This is deliberately NOT connected to the running app or Android widget.
/// A real activation still needs independently verified source and lock
/// witnesses, key recovery and an audited retention/expiry clock.
///
/// The transaction's money, ID, income/expense and SMS hash remain untouched.
/// Receipt bytes go to an encrypted SQLCipher trash table for 30 days, never
/// to plaintext disk. Permanent purge is deliberately NOT implemented.
class WaffraEncryptedReceiptRecycle {
  const WaffraEncryptedReceiptRecycle({
    required this.snapshot,
    required this.receiptVault,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  static const retention = Duration(days: 30);
  static const _trash = 'fresh_finance_receipt_recycle';
  static const _blobs = 'fresh_finance_receipt_recycle_blobs';

  final WaffraAtomicFinanceSnapshot snapshot;
  final WaffraEncryptedReceiptVault receiptVault;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  final bool experimentalEnabled;

  void _requireCandidate() {
    if (!experimentalEnabled ||
        !snapshot.experimentalEnabled ||
        !receiptVault.experimentalEnabled ||
        !identical(snapshot.store, receiptVault.store)) {
      throw StateError('Verified SQLCipher receipt recovery is unavailable.');
    }
  }

  Future<void> _ensureTables() async {
    await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS $_trash (
  entry_id TEXT PRIMARY KEY NOT NULL
    REFERENCES fresh_finance_entries(entry_id) ON DELETE RESTRICT,
  original_references TEXT NOT NULL,
  receipt_count INTEGER NOT NULL CHECK(receipt_count BETWEEN 1 AND 10),
  deleted_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL
)''');
    await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS $_blobs (
  entry_id TEXT NOT NULL REFERENCES $_trash(entry_id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_name TEXT NOT NULL,
  sha256_hex TEXT NOT NULL,
  byte_count INTEGER NOT NULL CHECK(byte_count > 0),
  encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id, position)
)''');
  }

  static Map<String, dynamic> _entry(
    WaffraFinanceSnapshotState state, String entryId,
  ) {
    final raw = state.values['entries'];
    if (raw is! String) {
      throw StateError('Encrypted finance ledger has no entry list.');
    }
    final rows = jsonDecode(raw);
    if (rows is! List || rows.any((element) => element is! Map)) {
      throw StateError('Encrypted finance ledger is malformed.');
    }
    final matching = rows.where(
      (row) => (row as Map)['id'] == entryId,
    ).toList();
    if (matching.length != 1) {
      throw StateError('Receipt owner is missing or duplicated.');
    }
    return Map<String, dynamic>.from(matching.single as Map);
  }

  static String _newLedger(
    WaffraFinanceSnapshotState state, String entryId, String? references,
  ) {
    final rows = jsonDecode(state.values['entries'] as String) as List;
    var replacements = 0;
    final updated = rows.map((value) {
      final item = Map<String, dynamic>.from(value as Map);
      if (item['id'] == entryId) {
        item['receiptPath'] = references;
        replacements++;
      }
      return item;
    }).toList();
    if (replacements != 1) {
      throw StateError('Ambiguous transaction identity during receipt edit.');
    }
    return jsonEncode(updated);
  }

  Future<void> _requireProjection(
    String entryId, Map<String, dynamic> ledger, int count,
  ) async {
    final sql = await snapshot.store.customSelect(
      'SELECT source_json,receipt_count FROM fresh_finance_entries '
      'WHERE entry_id=?',
      variables: [Variable.withString(entryId)],
    ).get();
    if (sql.length != 1 ||
        sql.single.read<int>('receipt_count') != count ||
        jsonEncode(jsonDecode(sql.single.read<String>('source_json'))) !=
            jsonEncode(ledger)) {
      throw StateError('Encrypted ledger and normalized entry disagree.');
    }
    // A second, older file/reference schema must not be silently abandoned.
    final other = await snapshot.store.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_receipts '
      'WHERE entry_id=?',
      variables: [Variable.withString(entryId)],
    ).getSingle();
    if (other.read<int>('n') != 0) {
      throw StateError('Unsupported receipt representation requires recovery.');
    }
  }

  static List<String> _references(String raw) {
    final result = raw.startsWith('[')
        ? jsonDecode(raw)
        : <dynamic>[raw];
    if (result is! List ||
        result.isEmpty ||
        result.any((value) => value is! String)) {
      throw StateError('Invalid encrypted receipt reference list.');
    }
    return List<String>.unmodifiable(result.cast<String>());
  }

  Future<List<WaffraEncryptedReceipt>> _readTrash(
    String entryId, int expectedCount,
  ) async {
    final rows = await snapshot.store.customSelect(
      'SELECT position,safe_name,sha256_hex,byte_count,encrypted_blob '
      'FROM $_blobs WHERE entry_id=? ORDER BY position',
      variables: [Variable.withString(entryId)],
    ).get();
    if (rows.length != expectedCount) {
      throw StateError('Archived encrypted receipt count differs.');
    }
    final result = <WaffraEncryptedReceipt>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final bytes = Uint8List.fromList(row.read<Uint8List>('encrypted_blob'));
      final checksum = sha256.convert(bytes).toString();
      final name = sha256.convert(utf8.encode(jsonEncode([entryId, i]))).toString()
          + '.bin';
      if (row.read<int>('position') != i ||
          row.read<String>('safe_name') != name ||
          bytes.isEmpty ||
          bytes.length > WaffraEncryptedReceiptVault.maxReceiptBytes ||
          row.read<int>('byte_count') != bytes.length ||
          row.read<String>('sha256_hex') != checksum) {
        throw StateError('Archived encrypted receipt integrity failure.');
      }
      result.add(WaffraEncryptedReceipt(
        entryId: entryId,
        position: i,
        safeName: name,
        sha256Hex: checksum,
        bytes: bytes,
      ));
    }
    return result;
  }

  Future<WaffraReceiptRecycleResult> moveToRecycle({
    required String entryId,
    required int expectedGeneration,
    required List<String> expectedImageHashes,
    required DateTime now,
    required bool userConfirmed,
  }) async {
    _requireCandidate();
    if (!userConfirmed) {
      throw StateError('User must confirm receipt removal.');
    }
    if (entryId.trim().isEmpty || entryId.length > 128 ||
        expectedGeneration < 0 ||
        expectedImageHashes.isEmpty ||
        expectedImageHashes.length >
            WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
        expectedImageHashes.any((digest) =>
          digest.length != 64 ||
          digest.split('').any(
            (character) => !'0123456789abcdef'.contains(character)))) {
      throw ArgumentError('Invalid receipt deletion witness.');
    }
    // M116 image replacement has its own SHA-256 CAS but intentionally
    // does not increment the ledger generation. Both witnesses are needed
    // so a stale delete cannot discard an image replaced in the meantime.
    final imageWitness = List<String>.unmodifiable(expectedImageHashes);
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final state = await snapshot.read();
        if (state.generation != expectedGeneration) {
          throw StateError('Stale receipt removal; reload financial source.');
        }
        await _ensureTables();
        final oldEntry = _entry(state, entryId);
        final refs = oldEntry['receiptPath'];
        if (refs is! String || refs.isEmpty) {
          throw StateError('There are no active encrypted receipts to remove.');
        }
        final originals = await receiptVault.readAll(entryId);
        final references = _references(refs);
        if (originals.length != references.length || originals.isEmpty ||
            originals.length != imageWitness.length ||
            originals.length > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
          throw StateError('Encrypted receipt references and images differ.');
        }
        for (var i = 0; i < originals.length; i++) {
          if (originals[i].sha256Hex != imageWitness[i]) {
            throw StateError('Receipt image changed; reload before deleting.');
          }
          if (originals[i].position != i ||
              !WaffraEncryptedReceiptReference.matches(
                references[i], entryId, i,
              )) {
            throw StateError('Receipt owner or position changed.');
          }
        }
        await _requireProjection(entryId, oldEntry, originals.length);
        final occupied = await snapshot.store.customSelect(
          'SELECT entry_id FROM $_trash WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (occupied.isNotEmpty) {
          throw StateError('Transaction already has archived receipts.');
        }
        final deletedAt = now.toUtc().millisecondsSinceEpoch;
        final expiresAt = deletedAt + retention.inMilliseconds;
        await snapshot.store.customStatement(
          'INSERT INTO $_trash '
          '(entry_id,original_references,receipt_count,deleted_at_ms,expires_at_ms) '
          'VALUES(?,?,?,?,?)',
          [entryId, refs, originals.length, deletedAt, expiresAt],
        );
        for (final receipt in originals) {
          await snapshot.store.customStatement(
            'INSERT INTO $_blobs '
            '(entry_id,position,safe_name,sha256_hex,byte_count,encrypted_blob) '
            'VALUES(?,?,?,?,?,?)',
            [
              entryId, receipt.position, receipt.safeName,
              receipt.sha256Hex, receipt.bytes.length, receipt.bytes,
            ],
          );
        }
        await _readTrash(entryId, originals.length);
        await snapshot.store.customStatement(
          'DELETE FROM fresh_finance_receipt_blobs WHERE entry_id=?',
          [entryId],
        );
        final newLedger = _newLedger(state, entryId, null);
        final newEntry = Map<String, dynamic>.from(oldEntry)
          ..['receiptPath'] = null;
        await snapshot.store.customStatement(
          'UPDATE fresh_finance_entries '
          'SET receipt_count=0,source_json=? WHERE entry_id=?',
          [jsonEncode(newEntry), entryId],
        );
        final next = Map<String, Object?>.from(state.values);
        next['entries'] = newLedger;
        final written = await snapshot.commit(
          expectedGeneration: state.generation,
          fullFinanceSnapshot: next,
        );
        if ((await receiptVault.readAll(entryId)).isNotEmpty) {
          throw StateError('Receipt deletion was not atomic.');
        }
        return WaffraReceiptRecycleResult(
          generation: written.generation,
          receiptCount: originals.length,
          expiresAtMs: expiresAt,
        );
      });
    });
  }

  Future<WaffraReceiptRecycleResult> restore({
    required String entryId,
    required int expectedGeneration,
    required DateTime now,
  }) async {
    _requireCandidate();
    if (entryId.trim().isEmpty || entryId.length > 128 ||
        expectedGeneration < 0) {
      throw ArgumentError('Invalid receipt restore witness.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final state = await snapshot.read();
        if (state.generation != expectedGeneration) {
          throw StateError('Stale receipt restore; reload financial source.');
        }
        await _ensureTables();
        final trash = await snapshot.store.customSelect(
          'SELECT original_references,receipt_count,expires_at_ms '
          'FROM $_trash WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (trash.length != 1) {
          throw StateError('No recoverable encrypted receipt exists.');
        }
        final row = trash.single;
        final expiry = row.read<int>('expires_at_ms');
        if (now.toUtc().millisecondsSinceEpoch >= expiry) {
          throw StateError('Encrypted receipt recovery window expired.');
        }
        final oldEntry = _entry(state, entryId);
        if (oldEntry['receiptPath'] != null) {
          throw StateError('Cannot restore over a new receipt.');
        }
        await _requireProjection(entryId, oldEntry, 0);
        final active = await receiptVault.readAll(entryId);
        if (active.isNotEmpty) {
          throw StateError('Active receipt already exists.');
        }
        final count = row.read<int>('receipt_count');
        if (count < 1 ||
            count > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
          throw StateError('Invalid archived encrypted receipt count.');
        }
        final archived = await _readTrash(entryId, count);
        final refs = row.read<String>('original_references');
        final references = _references(refs);
        if (references.length != count) {
          throw StateError('Archived receipt references are incomplete.');
        }
        for (var i = 0; i < count; i++) {
          if (!WaffraEncryptedReceiptReference.matches(
            references[i], entryId, i,
          )) {
            throw StateError('Archived receipt identity changed.');
          }
        }
        for (final picture in archived) {
          await snapshot.store.customStatement(
            'INSERT INTO fresh_finance_receipt_blobs '
            '(entry_id,position,safe_name,content_sha256,content_bytes,encrypted_blob) '
            'VALUES(?,?,?,?,?,?)',
            [
              entryId, picture.position, picture.safeName,
              picture.sha256Hex, picture.bytes.length, picture.bytes,
            ],
          );
        }
        final newEntry = Map<String, dynamic>.from(oldEntry)
          ..['receiptPath'] = refs;
        await snapshot.store.customStatement(
          'UPDATE fresh_finance_entries '
          'SET receipt_count=?,source_json=? WHERE entry_id=?',
          [count, jsonEncode(newEntry), entryId],
        );
        final next = Map<String, Object?>.from(state.values);
        next['entries'] = _newLedger(state, entryId, refs);
        final written = await snapshot.commit(
          expectedGeneration: state.generation,
          fullFinanceSnapshot: next,
        );
        final verification = await receiptVault.readAll(entryId);
        if (verification.length != count ||
            verification.asMap().entries.any((pair) =>
              pair.value.sha256Hex != archived[pair.key].sha256Hex)) {
          throw StateError('Restored receipt bytes failed integrity proof.');
        }
        await snapshot.store.customStatement(
          'DELETE FROM $_blobs WHERE entry_id=?', [entryId],
        );
        await snapshot.store.customStatement(
          'DELETE FROM $_trash WHERE entry_id=?', [entryId],
        );
        return WaffraReceiptRecycleResult(
          generation: written.generation,
          receiptCount: count,
          expiresAtMs: expiry,
        );
      });
    });
  }

  /// Returns only record identifiers and expiry times; receipt bytes never
  /// leave SQLCipher. No implicit trash purge is performed on expiry.
  Future<Map<String, int>> pendingRecoveries() async {
    _requireCandidate();
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      final exists = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$_trash'",
      ).get();
      if (exists.isEmpty) return const <String, int>{};
      final rows = await snapshot.store.customSelect(
        'SELECT entry_id,expires_at_ms FROM $_trash',
      ).get();
      return Map<String, int>.unmodifiable({
        for (final row in rows)
          row.read<String>('entry_id'): row.read<int>('expires_at_ms'),
      });
    });
  }
}

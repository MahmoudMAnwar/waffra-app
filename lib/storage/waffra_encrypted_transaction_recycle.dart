import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

class WaffraTransactionRecycleResult {
  const WaffraTransactionRecycleResult({
    required this.entryId,
    required this.generation,
    required this.receiptCount,
    required this.expiresAtMs,
    required this.restored,
  });

  final String entryId;
  final int generation;
  final int receiptCount;
  final int expiresAtMs;
  final bool restored;
}

/// Synthetic core proof only. A production caller MUST verify two genuinely
/// independent, authenticated UTC sources before constructing this value.
/// The SQLCipher core cannot itself attest the OS secure clock or a remote
/// signed clock. Consequently no production API wires this proof today.
class WaffraPurgeClockProof {
  const WaffraPurgeClockProof({
    required this.osWitnessUtc,
    required this.independentWitnessUtc,
  });

  final DateTime osWitnessUtc;
  final DateTime independentWitnessUtc;
}

class WaffraEncryptedExpiryPurgeResult {
  const WaffraEncryptedExpiryPurgeResult({
    required this.purged,
    required this.nextVerifiedClockMs,
    required this.remaining,
  });

  final int purged;
  final int nextVerifiedClockMs;
  final int remaining;
}

/// Candidate encrypted transaction-level undo, including every receipt byte.
/// SQLCipher finance and encrypted BLOBs remain recoverable for 30 days.
///
/// NOT a release gate: it requires an independently activated source and the
/// same native Home/Widget lock, and has no access to production app state.
/// Historical bank-SMS hashes are intentionally NOT deleted: an undone
/// transaction must not turn a repeated SMS into duplicate financial history.
class WaffraEncryptedTransactionRecycle {
  const WaffraEncryptedTransactionRecycle({
    required this.snapshot,
    required this.writerDirectory,
    required this.verifySourceUnderLock,
    this.experimentalEnabled = false,
  });

  static const retention = Duration(days: 30);
  static const _trash = 'fresh_finance_transaction_recycle';
  static const _images = 'fresh_finance_transaction_recycle_blobs';

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final Future<void> Function() verifySourceUnderLock;
  final bool experimentalEnabled;

  void _requireCandidate() {
    if (!experimentalEnabled || !snapshot.experimentalEnabled) {
      throw StateError('Encrypted transaction recycle is disabled.');
    }
  }

  Future<void> _ensureTables() async {
    await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS $_trash(
  entry_id TEXT PRIMARY KEY NOT NULL,
  source_json TEXT NOT NULL,
  source_sha256 TEXT NOT NULL,
  original_index INTEGER NOT NULL CHECK(original_index >= 0),
  receipt_count INTEGER NOT NULL CHECK(receipt_count BETWEEN 0 AND 10),
  deleted_at_ms INTEGER NOT NULL CHECK(deleted_at_ms >= 0),
  expires_at_ms INTEGER NOT NULL CHECK(expires_at_ms > deleted_at_ms)
)''');
    await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS $_images(
  entry_id TEXT NOT NULL REFERENCES $_trash(entry_id) ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_name TEXT NOT NULL,
  sha256_hex TEXT NOT NULL,
  byte_count INTEGER NOT NULL CHECK(byte_count > 0),
  encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id, position)
)''');
  }

  static List<Map<String, dynamic>> _decodeLedger(String? raw) {
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) {
      throw StateError('Encrypted transaction ledger is malformed.');
    }
    final seen = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).trim().isEmpty ||
          !seen.add(item['id'] as String)) {
        throw StateError('Encrypted ledger contains ambiguous identities.');
      }
      rows.add(Map<String, dynamic>.from(item));
    }
    return rows;
  }

  Future<void> _requireExactTypedLedger(
    List<Map<String, dynamic>> ledger,
  ) async {
    final rows = await snapshot.store.customSelect(
      'SELECT entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,source_json,receipt_count '
      'FROM fresh_finance_entries',
    ).get();
    if (rows.length != ledger.length) {
      throw StateError('SQLCipher ledger count differs from finance.');
    }
    final indexed = <String, Map<String, dynamic>>{
      for (final record in ledger) record['id'] as String: record,
    };
    final seen = <String>{};
    for (final row in rows) {
      final id = row.read<String>('entry_id');
      if (!seen.add(id) || !indexed.containsKey(id) ||
          jsonEncode(indexed[id]) !=
              jsonEncode(jsonDecode(row.read<String>('source_json')))) {
        throw StateError('SQLCipher ledger data differs from finance.');
      }
      // A matching JSON blob alone is NOT proof of typed SQL parity.
      // Financial dashboards and backup restore can read these typed numeric
      // columns independently, so tampering any one must block deletion.
      final original = indexed[id]!;
      final amount = original['amount'];
      final occurredAt = original['date'];
      final title = original['title'];
      final category = original['category'];
      if (amount is! num ||
          !WaffraLegacyPreflight.canRepresentHalalas(amount) ||
          original['income'] is! bool ||
          title is! String || category is! String ||
          occurredAt is! String ||
          DateTime.tryParse(occurredAt) == null ||
          row.read<String>('title') != title ||
          row.read<String>('category_snapshot') != category ||
          row.read<int>('amount_minor') != (amount * 100).round() ||
          row.read<int>('is_income') != (original['income'] == true ? 1 : 0) ||
          row.read<String>('occurred_iso') != occurredAt) {
        throw StateError('SQLCipher typed financial values differ from ledger.');
      }
      final refs = original['receiptPath'];
      final count = row.read<int>('receipt_count');
      if (count < 0 || count > WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
          (count == 0 && refs != null && refs != '') ||
          (count > 0 && (refs is! String || refs.isEmpty))) {
        throw StateError('SQLCipher receipt metadata is inconsistent.');
      }
    }
  }

  static List<String> _references(Object? raw, String entryId, int count) {
    if (count == 0) {
      if (raw != null && raw != '') {
        throw StateError('Receipt references exist without saved images.');
      }
      return const <String>[];
    }
    if (raw is! String || raw.isEmpty) {
      throw StateError('Receipt references are missing.');
    }
    final decoded = raw.startsWith('[') ? jsonDecode(raw) : <dynamic>[raw];
    if (decoded is! List || decoded.length != count) {
      throw StateError('Encrypted receipt references are incomplete.');
    }
    final result = <String>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! String ||
          !WaffraEncryptedReceiptReference.matches(item, entryId, i)) {
        throw StateError('Encrypted receipt owner/position mismatched.');
      }
      result.add(item);
    }
    return result;
  }

  Future<void> _requireNoOtherArchive(String entryId) async {
    // A receipt-only recycle stores its images under an active entry FK.
    // Do not remove that owner while its independent 30-day clock is active.
    for (final name in const <String>[
      'fresh_finance_receipt_recycle',
      'fresh_finance_receipt_recycle_blobs',
      'fresh_finance_receipts',
    ]) {
      final found = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(name)],
      ).get();
      if (found.isEmpty) continue;
      final count = await snapshot.store.customSelect(
        'SELECT count(*) AS n FROM $name WHERE entry_id=?',
        variables: [Variable.withString(entryId)],
      ).getSingle();
      if (count.read<int>('n') != 0) {
        throw StateError('Transaction has another receipt representation.');
      }
    }
  }

  Future<WaffraTransactionRecycleResult> delete({
    required WaffraFinanceSnapshotState baseline,
    required String entryId,
    required List<String> expectedImageHashes,
    required DateTime now,
    required bool userConfirmed,
  }) async {
    _requireCandidate();
    if (!userConfirmed || entryId.trim().isEmpty || entryId.length > 128) {
      throw StateError('An explicitly confirmed transaction is required.');
    }
    final witness = List<String>.unmodifiable(expectedImageHashes);
    if (witness.length > WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
        witness.any((hash) =>
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))) {
      throw ArgumentError('Encrypted receipt SHA witnesses are invalid.');
    }
    final at = now.toUtc().millisecondsSinceEpoch;
    if (at < 0 || at > 8640000000000000 - retention.inMilliseconds) {
      throw ArgumentError('Invalid signed transaction deletion time.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        if (current.generation != baseline.generation ||
            current.digest != baseline.digest) {
          throw StateError('Financial transaction changed; reload to delete.');
        }
        final ledger = _decodeLedger(current.values['entries'] as String?);
        await _requireExactTypedLedger(ledger);
        final atIndex = ledger.indexWhere((row) => row['id'] == entryId);
        if (atIndex < 0) {
          throw StateError('Transaction no longer exists.');
        }
        await _ensureTables();
        await _requireNoOtherArchive(entryId);
        final occupied = await snapshot.store.customSelect(
          'SELECT entry_id FROM $_trash WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (occupied.isNotEmpty) {
          throw StateError('Transaction already has pending recovery.');
        }
        final record = ledger[atIndex];
        final vault = WaffraEncryptedReceiptVault(
          store: snapshot.store,
          experimentalEnabled: true,
        );
        final receipts = await vault.readAll(entryId);
        _references(record['receiptPath'], entryId, receipts.length);
        if (witness.length != receipts.length) {
          throw StateError('Receipt witness was not captured from this entry.');
        }
        for (var i = 0; i < receipts.length; i++) {
          if (receipts[i].position != i ||
              receipts[i].sha256Hex != witness[i]) {
            throw StateError('Receipt was replaced since screen confirmation.');
          }
        }
        final until = at + retention.inMilliseconds;
        await snapshot.store.customStatement(
          'INSERT INTO $_trash(entry_id,source_json,source_sha256,'
          'original_index,receipt_count,deleted_at_ms,expires_at_ms) '
          'VALUES (?,?,?,?,?,?,?)',
          [entryId, jsonEncode(record),
           sha256.convert(utf8.encode(jsonEncode(record))).toString(),
           atIndex, receipts.length, at, until],
        );
        for (final receipt in receipts) {
          await snapshot.store.customStatement(
            'INSERT INTO $_images(entry_id,position,safe_name,sha256_hex,'
            'byte_count,encrypted_blob) VALUES (?,?,?,?,?,?)',
            [entryId, receipt.position, receipt.safeName,
             receipt.sha256Hex, receipt.bytes.length, receipt.bytes],
          );
        }
        final activeBlobTable = await snapshot.store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='fresh_finance_receipt_blobs'",
        ).get();
        if (activeBlobTable.isNotEmpty) {
          await snapshot.store.customStatement(
            'DELETE FROM fresh_finance_receipt_blobs WHERE entry_id=?',
            [entryId],
          );
        } else if (receipts.isNotEmpty) {
          throw StateError('Verified receipt BLOB table disappeared.');
        }
        await snapshot.store.customStatement(
          'DELETE FROM fresh_finance_entries WHERE entry_id=?', [entryId],
        );
        final nextLedger = List<Map<String, dynamic>>.from(ledger)
          ..removeAt(atIndex);
        final next = Map<String, Object?>.from(current.values)
          ..['entries'] = jsonEncode(nextLedger);
        // SMS hashes remain untouched to protect duplicate-import history.
        final written = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
        final active = await snapshot.store.customSelect(
          'SELECT entry_id FROM fresh_finance_entries WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        final archived = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM $_images WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).getSingle();
        if (active.isNotEmpty ||
            archived.read<int>('n') != receipts.length) {
          throw StateError('Encrypted delete/receipt recycle was not atomic.');
        }
        return WaffraTransactionRecycleResult(
          entryId: entryId,
          generation: written.generation,
          receiptCount: receipts.length,
          expiresAtMs: until,
          restored: false,
        );
      });
    });
  }

  Future<WaffraTransactionRecycleResult> restore({
    required WaffraFinanceSnapshotState baseline,
    required String entryId,
    required DateTime now,
  }) async {
    _requireCandidate();
    if (entryId.trim().isEmpty || entryId.length > 128) {
      throw ArgumentError('Invalid transaction recovery identity.');
    }
    final observed = now.toUtc().millisecondsSinceEpoch;
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        if (current.generation != baseline.generation ||
            current.digest != baseline.digest) {
          throw StateError('Transaction restore witness is stale.');
        }
        final ledger = _decodeLedger(current.values['entries'] as String?);
        await _requireExactTypedLedger(ledger);
        await _ensureTables();
        final matches = await snapshot.store.customSelect(
          'SELECT source_json,source_sha256,original_index,receipt_count,'
          'deleted_at_ms,expires_at_ms FROM $_trash WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (matches.length != 1 || ledger.any((x) => x['id'] == entryId)) {
          throw StateError('No single recoverable transaction exists.');
        }
        final archived = matches.single;
        final deleted = archived.read<int>('deleted_at_ms');
        final expiry = archived.read<int>('expires_at_ms');
        if (deleted < 0 ||
            expiry - deleted != retention.inMilliseconds ||
            observed < deleted || observed >= expiry) {
          throw StateError('Transaction recovery clock expired or rolled back.');
        }
        final archiveJson = archived.read<String>('source_json');
        if (sha256.convert(utf8.encode(archiveJson)).toString() !=
            archived.read<String>('source_sha256')) {
          throw StateError('Archived transaction financial checksum differs.');
        }
        final record = jsonDecode(archiveJson);
        if (record is! Map<String, dynamic> || record['id'] != entryId ||
            record['title'] is! String ||
            record['category'] is! String ||
            record['income'] is! bool ||
            record['date'] is! String ||
            DateTime.tryParse(record['date'] as String) == null ||
            record['amount'] is! num) {
          throw StateError('Archived financial record is invalid.');
        }
        final preflight = WaffraLegacyPreflight.inspect(
          <String, Object?>{'entries': jsonEncode([record])},
        );
        if (!preflight.canStage) {
          throw StateError('Archived transaction cannot be restored.');
        }
        final count = archived.read<int>('receipt_count');
        if (count < 0 ||
            count > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
          throw StateError('Archived receipt count is malformed.');
        }
        _references(record['receiptPath'], entryId, count);
        await _requireNoOtherArchive(entryId);
        final active = await snapshot.store.customSelect(
          'SELECT entry_id FROM fresh_finance_entries WHERE entry_id=?',
          variables: [Variable.withString(entryId)],
        ).get();
        if (active.isNotEmpty) {
          throw StateError('Cannot overwrite an active transaction.');
        }
        final parts = await snapshot.store.customSelect(
          'SELECT position,safe_name,sha256_hex,byte_count,encrypted_blob '
          'FROM $_images WHERE entry_id=? ORDER BY position',
          variables: [Variable.withString(entryId)],
        ).get();
        if (parts.length != count) {
          throw StateError('Archived receipt batch is missing bytes.');
        }
        final copied = <Uint8List>[];
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          final bytes = Uint8List.fromList(part.read<Uint8List>('encrypted_blob'));
          final safeName = sha256.convert(
            utf8.encode(jsonEncode([entryId, i])),
          ).toString() + '.bin';
          if (part.read<int>('position') != i ||
              part.read<String>('safe_name') != safeName ||
              bytes.isEmpty ||
              bytes.length > WaffraEncryptedReceiptVault.maxReceiptBytes ||
              part.read<int>('byte_count') != bytes.length ||
              part.read<String>('sha256_hex') !=
                  sha256.convert(bytes).toString()) {
            throw StateError('Archived receipt checksum or owner differs.');
          }
          copied.add(bytes);
        }
        final originalPosition = archived.read<int>('original_index');
        if (originalPosition < 0) {
          throw StateError('Archived transaction ordering is invalid.');
        }
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
          [entryId, record['title'], record['category'],
           ((record['amount'] as num) * 100).round(),
           record['income'] == true ? 1 : 0, record['date'], count,
           jsonEncode(record)],
        );
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          await snapshot.store.customStatement(
            'INSERT INTO fresh_finance_receipt_blobs '
            '(entry_id,position,safe_name,content_sha256,'
            'content_bytes,encrypted_blob) VALUES (?,?,?,?,?,?)',
            [entryId, i, part.read<String>('safe_name'),
             part.read<String>('sha256_hex'), copied[i].length, copied[i]],
          );
        }
        final nextLedger = List<Map<String, dynamic>>.from(ledger)
          ..insert(originalPosition > ledger.length ? ledger.length : originalPosition,
              Map<String, dynamic>.from(record));
        final next = Map<String, Object?>.from(current.values)
          ..['entries'] = jsonEncode(nextLedger);
        final written = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
        if (count > 0) {
          final vault = WaffraEncryptedReceiptVault(
            store: snapshot.store,
            experimentalEnabled: true,
          );
          final restored = await vault.readAll(entryId);
          if (restored.length != count ||
              restored.asMap().entries.any((pair) =>
                  pair.value.sha256Hex !=
                      parts[pair.key].read<String>('sha256_hex'))) {
            throw StateError('Restored receipt images failed byte parity.');
          }
        }
        await snapshot.store.customStatement(
          'DELETE FROM $_images WHERE entry_id=?', [entryId],
        );
        await snapshot.store.customStatement(
          'DELETE FROM $_trash WHERE entry_id=?', [entryId],
        );
        return WaffraTransactionRecycleResult(
          entryId: entryId,
          generation: written.generation,
          receiptCount: count,
          expiresAtMs: expiry,
          restored: true,
        );
      });
    });
  }

  /// Permanently erase ONLY expired transaction-trash rows and their
  /// encrypted invoice BLOBs. No active money, receipts, SMS hashes, canonical
  /// snapshot or Widget generation are modified. This is opt-in and disabled
  /// by default; the caller must independently authenticate BOTH UTC sources.
  ///
  /// The SQL transaction verifies all selected archive JSON and BLOB digests
  /// before deleting a single row. A failure rolls back the entire batch.
  Future<WaffraEncryptedExpiryPurgeResult> purgeExpired({
    required Future<WaffraPurgeClockProof> Function()
        verifyIndependentClockUnderLock,
    int maxBatch = 1,
  }) async {
    _requireCandidate();
    if (maxBatch < 1 || maxBatch > 2) {
      throw ArgumentError('At most two archived transactions per purge.');
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      final proof = await verifyIndependentClockUnderLock();
      final osMs = proof.osWitnessUtc.toUtc().millisecondsSinceEpoch;
      final otherMs =
          proof.independentWitnessUtc.toUtc().millisecondsSinceEpoch;
      if (osMs < 0 || otherMs < 0 ||
          osMs > 8640000000000000 ||
          otherMs > 8640000000000000 ||
          (osMs - otherMs).abs() > const Duration(minutes: 2).inMilliseconds) {
        throw StateError('Independent expiry clock witnesses disagree.');
      }
      // Both authorities must agree that retention has fully elapsed.
      final trustedMs = osMs < otherMs ? osMs : otherMs;
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        final ledger = _decodeLedger(current.values['entries'] as String?);
        await _requireExactTypedLedger(ledger);

        await _ensureTables();
        await snapshot.store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_finance_transaction_recycle_clock(
  singleton INTEGER PRIMARY KEY CHECK(singleton=1),
  last_verified_utc_ms INTEGER NOT NULL CHECK(last_verified_utc_ms >= 0)
)''');
        final savedClock = await snapshot.store.customSelect(
          'SELECT last_verified_utc_ms FROM '
          'fresh_finance_transaction_recycle_clock WHERE singleton=1',
        ).get();
        if (savedClock.length > 1 ||
            (savedClock.isNotEmpty &&
             trustedMs <
                 savedClock.single.read<int>('last_verified_utc_ms'))) {
          throw StateError('Encrypted expiry clock moved backwards.');
        }

        final archive = await snapshot.store.customSelect(
          'SELECT entry_id,source_json,source_sha256,receipt_count,'
          'deleted_at_ms,expires_at_ms FROM $_trash '
          'ORDER BY expires_at_ms ASC,entry_id ASC',
        ).get();
        final activeIds = ledger.map((row) => row['id'] as String).toSet();
        final targets = <Map<String, Object?>>[];
        final archiveIds = <String>{};
        for (final row in archive) {
          final id = row.read<String>('entry_id');
          final deletedAt = row.read<int>('deleted_at_ms');
          final expiry = row.read<int>('expires_at_ms');
          if (id.trim().isEmpty || id.length > 128 ||
              !archiveIds.add(id) ||
              deletedAt < 0 ||
              expiry - deletedAt != retention.inMilliseconds ||
              activeIds.contains(id)) {
            throw StateError('Encrypted transaction trash metadata is corrupt.');
          }
          if (expiry > trustedMs || targets.length >= maxBatch) continue;
          final raw = row.read<String>('source_json');
          if (sha256.convert(utf8.encode(raw)).toString() !=
              row.read<String>('source_sha256')) {
            throw StateError('Expired archived financial checksum differs.');
          }
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic> || decoded['id'] != id ||
              !WaffraLegacyPreflight.inspect(
                <String, Object?>{'entries': jsonEncode([decoded])},
              ).canStage) {
            throw StateError('Expired encrypted transaction is malformed.');
          }
          final count = row.read<int>('receipt_count');
          if (count < 0 ||
              count > WaffraEncryptedReceiptVault.maxReceiptsPerEntry) {
            throw StateError('Expired receipt count is invalid.');
          }
          _references(decoded['receiptPath'], id, count);
          await _requireNoOtherArchive(id);
          final sqlParts = await snapshot.store.customSelect(
            'SELECT position,safe_name,sha256_hex,byte_count,encrypted_blob '
            'FROM $_images WHERE entry_id=? ORDER BY position',
            variables: [Variable.withString(id)],
          ).get();
          if (sqlParts.length != count) {
            throw StateError('Expired encrypted receipts are incomplete.');
          }
          for (var i = 0; i < count; i++) {
            final part = sqlParts[i];
            final bytes = part.read<Uint8List>('encrypted_blob');
            final filename = sha256.convert(
              utf8.encode(jsonEncode([id, i])),
            ).toString() + '.bin';
            if (part.read<int>('position') != i ||
                part.read<String>('safe_name') != filename ||
                bytes.isEmpty ||
                bytes.length > WaffraEncryptedReceiptVault.maxReceiptBytes ||
                part.read<int>('byte_count') != bytes.length ||
                part.read<String>('sha256_hex') !=
                    sha256.convert(bytes).toString()) {
              throw StateError('Expired encrypted invoice bytes differ.');
            }
          }
          targets.add(<String, Object?>{'id': id, 'count': count});
        }

        // Nothing is physically deleted before the entire target set passes
        // financial, receipt-owner and byte-integrity validation.
        for (final target in targets) {
          final id = target['id'] as String;
          await snapshot.store.customStatement(
            'DELETE FROM $_images WHERE entry_id=?', [id],
          );
          await snapshot.store.customStatement(
            'DELETE FROM $_trash WHERE entry_id=?', [id],
          );
          final remainingPart = await snapshot.store.customSelect(
            'SELECT count(*) AS n FROM $_images WHERE entry_id=?',
            variables: [Variable.withString(id)],
          ).getSingle();
          if (remainingPart.read<int>('n') != 0) {
            throw StateError('Expired archive BLOB purge was incomplete.');
          }
        }
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_transaction_recycle_clock'
          '(singleton,last_verified_utc_ms) VALUES (1,?) '
          'ON CONFLICT(singleton) DO UPDATE SET '
          'last_verified_utc_ms=excluded.last_verified_utc_ms',
          [trustedMs],
        );
        final after = await snapshot.read();
        if (after.generation != current.generation ||
            after.digest != current.digest) {
          throw StateError('Expiry purge unexpectedly changed active finance.');
        }
        final left = await snapshot.store.customSelect(
          'SELECT count(*) AS n FROM $_trash',
        ).getSingle();
        return WaffraEncryptedExpiryPurgeResult(
          purged: targets.length,
          remaining: left.read<int>('n'),
          nextVerifiedClockMs: trustedMs,
        );
      });
    });
  }

  /// Metadata only. No receipt or transaction JSON leaves the SQLCipher DB.
  Future<Map<String, int>> pendingRecoveries() async {
    _requireCandidate();
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      await verifySourceUnderLock();
      final present = await snapshot.store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(_trash)],
      ).get();
      if (present.isEmpty) return const <String, int>{};
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

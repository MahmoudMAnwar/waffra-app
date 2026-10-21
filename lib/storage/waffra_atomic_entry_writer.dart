import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import 'waffra_cloud_cipher.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_financial_write_gate.dart';
import 'waffra_ledger_repository.dart';
import 'waffra_sync_outbox.dart';

/// Draft-only single-transaction financial entry + encrypted outbox mutation.
///
/// This is NOT called by main.dart or any background/UI writer. There is no
/// Firebase SDK, server operation, automatic migration, or live data cutover.
/// An external verified encrypted SQLite store and per-vault E2EE key are
/// required. The existing SharedPreferences source is never modified.
///
/// This experiment coordinates a working_ledger_entries mutation, its cloud
/// outbox entry, and the idempotency journal inside ONE SQLite transaction.
/// Every application writer must be routed through one gate before activation.
class WaffraDraftAtomicEntryWriter {
  WaffraDraftAtomicEntryWriter({
    required this.database,
    required this.gate,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore database;
  final WaffraFinancialWriteGate gate;
  final bool experimentalEnabled;

  static void _validateIdentity(String vaultId, String mutationId,
      String deviceId, WaffraLedgerItem item) {
    for (final value in [vaultId, mutationId, deviceId, item.id]) {
      if (value.trim().isEmpty || value.length > 128 || value.contains('/')) {
        throw ArgumentError('Invalid encrypted financial mutation identity.');
      }
    }
    if (item.amountMinor < 0 || item.amountMinor > 9007199254740991 ||
        item.version <= 0 || item.title.trim().isEmpty ||
        item.title.length > 4096 || item.category.trim().isEmpty ||
        item.category.length > 256) {
      throw ArgumentError('Invalid financial entry data.');
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T|$)')
        .firstMatch(item.occurredIso);
    if (match == null || DateTime.tryParse(item.occurredIso) == null) {
      throw ArgumentError('Invalid transaction date.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final d = DateTime.utc(year, month, day);
    if (d.year != year || d.month != month || d.day != day) {
      throw ArgumentError('Impossible transaction calendar date.');
    }
  }

  static const _journalDdl = '''
CREATE TABLE IF NOT EXISTS working_atomic_entry_mutations(
  vault_id TEXT NOT NULL,
  mutation_id TEXT NOT NULL,
  entry_id TEXT NOT NULL,
  local_version INTEGER NOT NULL,
  payload_sha256 TEXT NOT NULL,
  deleted INTEGER NOT NULL CHECK(deleted IN (0,1)),
  PRIMARY KEY(vault_id,mutation_id),
  FOREIGN KEY(vault_id,entry_id)
    REFERENCES working_ledger_entries(vault_id,entry_id)
)''';

  Future<WaffraAtomicEntryResult> commit({
    required String vaultId,
    required String mutationId,
    required String deviceId,
    required int expectedVersion,
    required WaffraLedgerItem item,
    required SecretKey vaultKey,
    bool deleted = false,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Atomic financial mutation prototype is disabled.');
    }
    _validateIdentity(vaultId, mutationId, deviceId, item);
    if (item.deleted || expectedVersion < 0 ||
        item.version != expectedVersion + 1 ||
        (deleted && expectedVersion == 0)) {
      throw ArgumentError('Invalid expected version or operation.');
    }
    final amountSar = item.amountMinor / 100;
    if (!amountSar.isFinite ||
        (amountSar * 100).round() != item.amountMinor) {
      throw ArgumentError('Amount cannot round-trip as SAR.');
    }
    final remoteRecord = <String, dynamic>{
      'id': item.id,
      'title': item.title,
      'category': item.category,
      'amount': amountSar,
      'income': item.isIncome,
      'date': item.occurredIso,
    };
    final fingerprint = sha256.convert(utf8.encode(jsonEncode([
      vaultId, mutationId, deviceId, item.id, item.title, item.category,
      item.amountMinor, item.isIncome, item.occurredIso, item.version,
      expectedVersion, deleted,
    ]))).toString();

    // Encryption happens before entering the transaction. Replayed mutation
    // IDs must consult the journal BEFORE enqueuing freshly randomized bytes.
    // The journal explicitly prevents mutation reuse with a changed payload.
    return gate.runWrite(() => database.transaction(() async {
      final prep = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='working_ledger_preparations'",
      ).get();
      if (prep.isEmpty) throw StateError('Verified ledger not initialized.');
      final confirmed = await database.customSelect(
        'SELECT source_sha256 FROM working_ledger_preparations WHERE vault_id=?',
        variables: [Variable.withString(vaultId)],
      ).getSingleOrNull();
      if (confirmed == null) throw StateError('Unverified vault.');

      await database.customStatement(_journalDdl);
      final prior = await database.customSelect('''
SELECT entry_id,local_version,payload_sha256,deleted
FROM working_atomic_entry_mutations WHERE vault_id=? AND mutation_id=?
''', variables: [
        Variable.withString(vaultId), Variable.withString(mutationId),
      ]).getSingleOrNull();
      if (prior != null) {
        if (prior.read<String>('entry_id') != item.id ||
            prior.read<int>('local_version') != item.version ||
            prior.read<String>('payload_sha256') != fingerprint ||
            prior.read<int>('deleted') != (deleted ? 1 : 0)) {
          throw StateError('Mutation ID was reused with different contents.');
        }
        return WaffraAtomicEntryResult(
          mutationId: mutationId, version: item.version, alreadyApplied: true,
        );
      }

      final previous = await database.customSelect('''
SELECT local_version,is_deleted FROM working_ledger_entries
WHERE vault_id=? AND entry_id=?
''', variables: [
        Variable.withString(vaultId), Variable.withString(item.id),
      ]).getSingleOrNull();
      if (previous == null) {
        if (expectedVersion != 0 || deleted) {
          throw StateError('Cannot update/delete a missing financial entry.');
        }
      } else if (previous.read<int>('local_version') != expectedVersion ||
          previous.read<int>('is_deleted') == 1) {
        throw StateError('Stale, duplicate or deleted financial entry.');
      }

      // Real encryption. Only explicitly allowlisted entry fields may leave a
      // device in a future opt-in sync. Neither the raw SMS nor receipt paths
      // enter this record.
      final encrypted = await WaffraCloudCipher().encrypt(
        vaultKey: vaultKey,
        vaultId: vaultId,
        kind: 'entry',
        recordId: item.id,
        deviceId: deviceId,
        mutationId: mutationId,
        localVersion: item.version,
        record: remoteRecord,
      );

      if (previous == null) {
        await database.customStatement('''
INSERT INTO working_ledger_entries(
  vault_id,entry_id,title,category_snapshot,amount_minor,is_income,
  occurred_iso,local_version,is_deleted
) VALUES (?,?,?,?,?,?,?,?,0)
''', [
          vaultId, item.id, item.title, item.category, item.amountMinor,
          item.isIncome ? 1 : 0, item.occurredIso, item.version,
        ]);
      } else {
        await database.customStatement('''
UPDATE working_ledger_entries SET
 title=?,category_snapshot=?,amount_minor=?,is_income=?,
 occurred_iso=?,local_version=?,is_deleted=?
WHERE vault_id=? AND entry_id=? AND local_version=? AND is_deleted=0
''', [
          item.title, item.category, item.amountMinor,
          item.isIncome ? 1 : 0, item.occurredIso, item.version,
          deleted ? 1 : 0, vaultId, item.id, expectedVersion,
        ]);
        final affected = await database.customSelect(
          'SELECT changes() AS changed',
        ).getSingle();
        if (affected.read<int>('changed') != 1) {
          throw StateError('Concurrent financial edit rejected.');
        }
      }
      // Drift nested transactions use savepoints; if outbox enqueue throws,
      // its exception aborts the OUTER ledger transaction too.
      await WaffraEncryptedCloudOutbox(database).enqueue(
        vaultId: vaultId, envelope: encrypted, deleted: deleted);
      await database.customStatement('''
INSERT INTO working_atomic_entry_mutations(
  vault_id,mutation_id,entry_id,local_version,payload_sha256,deleted)
VALUES (?,?,?,?,?,?)
''', [
        vaultId, mutationId, item.id, item.version, fingerprint,
        deleted ? 1 : 0,
      ]);
      return WaffraAtomicEntryResult(
        mutationId: mutationId, version: item.version, alreadyApplied: false,
      );
    }));
  }
}

class WaffraAtomicEntryResult {
  const WaffraAtomicEntryResult({
    required this.mutationId,
    required this.version,
    required this.alreadyApplied,
  });
  final String mutationId;
  final int version;
  final bool alreadyApplied;
}

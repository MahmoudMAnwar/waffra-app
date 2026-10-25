import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_experimental_writer_gate.dart';

/// Encrypted-only repair of a legacy SMS row saved without its original note.
/// This does not create transactions, move live source markers, access
/// SharedPreferences, or modify actual users. It is disabled by default.
class WaffraEncryptedLegacySmsReattachment {
  const WaffraEncryptedLegacySmsReattachment({
    required this.snapshot,
    required this.writerDirectory,
    required this.verifyEncryptedSourceUnderLock,
    this.experimentalEnabled = false,
  });

  final WaffraAtomicFinanceSnapshot snapshot;
  final Directory writerDirectory;
  final Future<void> Function() verifyEncryptedSourceUnderLock;
  final bool experimentalEnabled;

  /// Same SHA-256 normalization used by the shipped SMS duplicate detector.
  /// NEVER normalize the original SMS text itself before encrypted storage.
  static String bankSmsFingerprint(String message) {
    const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
    final normalized = message.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final c = m.group(0)!;
      final ar = arabic.indexOf(c);
      return (ar >= 0 ? ar : persian.indexOf(c)).toString();
    }).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// A legacy hash list is not a per-entry map! The user must select exactly
  /// one transaction and review its immutable title/category/date, while
  /// independent SMS parsing verifies direction and minor-unit amount.
  /// Neither hash alone nor matching amount alone authorizes attachment.
  Future<int> attachExactOriginal({
    required String entryId,
    required String originalSms,
    required String expectedHash,
    required int verifiedAmountMinor,
    required bool verifiedIncome,
    required String confirmedTitle,
    required String confirmedCategory,
    required String confirmedDate,
    required int expectedGeneration,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted note recovery disabled by default.');
    }
    if (!userConfirmed || expectedGeneration < 0 ||
        entryId.trim().isEmpty || entryId.length > 128 ||
        confirmedTitle.isEmpty || confirmedCategory.isEmpty ||
        DateTime.tryParse(confirmedDate) == null ||
        verifiedAmountMinor <= 0 || verifiedAmountMinor > 100000000000 ||
        originalSms.trim().isEmpty || originalSms.runes.length > 16000 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
        bankSmsFingerprint(originalSms) != expectedHash) {
      throw StateError('SMS association has not been confirmed.');
    }
    final note = originalSms; // Frozen; never exported to plaintext storage.
    final hash = expectedHash;
    final target = entryId;
    final gate = WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory, experimentalEnabled: true,
    );
    return gate.withExclusiveAccess(() async {
      // Required independent active-source witness INSIDE the shared lock.
      await verifyEncryptedSourceUnderLock();
      return snapshot.store.transaction(() async {
        final before = await snapshot.read();
        if (before.generation != expectedGeneration) {
          throw StateError('Financial source changed during SMS review.');
        }
        final entriesRaw = before.values['entries'];
        final hashes = before.values['waffra_sms_hashes_v1'];
        if (entriesRaw is! String || hashes is! List<String> ||
            hashes.where((h) => h == hash).length != 1) {
          throw StateError('SMS fingerprint is not in the encrypted ledger.');
        }
        final decoded = jsonDecode(entriesRaw);
        if (decoded is! List || decoded.any((x) => x is! Map)) {
          throw StateError('Encrypted finance ledger is invalid.');
        }
        final rows = decoded.map<Map<String, Object?>>(
          (r) => Map<String, Object?>.from(r as Map)).toList();
        final ids = rows.map((r) => r['id']).toList();
        if (ids.length != ids.toSet().length ||
            ids.where((id) => id == target).length != 1) {
          throw StateError('Legacy transaction ID is not unique.');
        }
        final selectedIndex = rows.indexWhere((r) => r['id'] == target);
        final selected = rows[selectedIndex];
        final amount = selected['amount'];
        if (selected['sourceType'] != 'sms' ||
            selected['title'] != confirmedTitle ||
            selected['category'] != confirmedCategory ||
            selected['date'] != confirmedDate ||
            selected['income'] != verifiedIncome ||
            amount is! num || !amount.toDouble().isFinite ||
            (amount * 100).round() != verifiedAmountMinor ||
            (selected['notes'] != null && selected['notes'] != '')) {
          throw StateError('Chosen transaction is not a matching blank SMS.');
        }

        // Verify the complete existing SQL/canonical projection before edits.
        final sqlRows = await snapshot.store.customSelect(
          'SELECT entry_id,source_json,amount_minor,is_income '
          'FROM fresh_finance_entries').get();
        if (sqlRows.length != rows.length) {
          throw StateError('SQL and canonical finance counts differ.');
        }
        final sqlById = <String, Map<String, Object?>>{};
        for (final row in sqlRows) {
          final id = row.read<String>('entry_id');
          if (sqlById.containsKey(id)) {
            throw StateError('Duplicate SQL finance ID.');
          }
          sqlById[id] = {
            'source': row.read<String>('source_json'),
            'amount': row.read<int>('amount_minor'),
            'income': row.read<int>('is_income'),
          };
        }
        for (final row in rows) {
          final id = row['id'];
          if (id is! String || !sqlById.containsKey(id) ||
              sqlById[id]!['source'] != jsonEncode(row) ||
              row['amount'] is! num ||
              sqlById[id]!['amount'] != ((row['amount'] as num) * 100).round() ||
              sqlById[id]!['income'] != (row['income'] == true ? 1 : 0)) {
            throw StateError('Existing encrypted finance projection disagrees.');
          }
          final existingNote = row['notes'];
          if (id != target && existingNote is String &&
              existingNote.isNotEmpty &&
              bankSmsFingerprint(existingNote) == hash) {
            throw StateError('This SMS already belongs to another transaction.');
          }
        }
        final typedHashes = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes').get();
        final sqlHashes = typedHashes.map(
          (r) => r.read<String>('message_hash')).toList();
        if (sqlHashes.length != hashes.length ||
            sqlHashes.toSet().length != hashes.length ||
            !sqlHashes.toSet().containsAll(hashes)) {
          throw StateError('Encrypted SMS hash indexes disagree.');
        }

        final patched = Map<String, Object?>.from(selected);
        patched['notes'] = note;
        rows[selectedIndex] = patched;
        await snapshot.store.customStatement(
          'UPDATE fresh_finance_entries SET source_json=? WHERE entry_id=?',
          [jsonEncode(patched), target],
        );
        final next = Map<String, Object?>.from(before.values);
        next['entries'] = jsonEncode(rows);
        final written = await snapshot.commit(
          expectedGeneration: before.generation,
          fullFinanceSnapshot: next,
        );
        final canonical = jsonDecode(written.values['entries'] as String);
        if (canonical is! List || canonical.length != rows.length) {
          throw StateError('Encrypted SMS canonical row count mismatch.');
        }
        final matching = canonical.where(
          (r) => r is Map && r['id'] == target).toList();
        final sql = await snapshot.store.customSelect(
          'SELECT source_json FROM fresh_finance_entries WHERE entry_id=?',
          variables: [Variable.withString(target)],
        ).get();
        if (matching.length != 1 ||
            (matching.single as Map)['notes'] != note ||
            sql.length != 1 ||
            (jsonDecode(sql.single.read<String>('source_json')) as Map)['notes'] != note ||
            written.generation != before.generation + 1) {
          // Outer SQLCipher transaction rolls back both projections here.
          throw StateError('Original SMS byte-exact encrypted parity failed.');
        }
        return written.generation;
      });
    });
  }
}

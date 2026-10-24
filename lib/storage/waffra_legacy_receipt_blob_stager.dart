import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';

class WaffraReceiptStagingReport {
  const WaffraReceiptStagingReport({
    required this.ledgerRecords,
    required this.receiptBlobs,
    required this.receiptBytes,
    required this.legacyFinanceDigest,
  });

  final int ledgerRecords;
  final int receiptBlobs;
  final int receiptBytes;
  final String legacyFinanceDigest;
}

/// Disposable **copy-only** conversion of verified finance transactions and
/// local receipts to relational SQLCipher rows plus encrypted receipt BLOBs.
///
/// It NEVER alters/deletes the legacy finance source, never writes activation
/// markers and MUST NOT be used as a live cutover until every app/widget
/// reader and writer has been routed through the encrypted source.
///
/// The M52 whole finance snapshot is required as a separate immutable witness
/// before any relational projection is permitted.
class WaffraLegacyReceiptBlobStager {
  const WaffraLegacyReceiptBlobStager({
    required this.store,
    required this.coordinator,
    required this.trustedRoots,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final WaffraLegacyFinanceWriterCoordinator coordinator;
  final List<Directory> trustedRoots;
  final bool experimentalEnabled;

  static const maxReceiptBytes = 8 * 1024 * 1024;
  static const maxReceiptsPerEntry = 10;
  static const _receiptTable = 'fresh_finance_receipt_blobs';

  static String _canonicalJson(Map<String, Object?> values) {
    final keys = values.keys.toList()..sort();
    return jsonEncode({for (final key in keys) key: values[key]});
  }

  static List<String> _paths(Object? raw) {
    if (raw == null || raw == '') return [];
    if (raw is! String) throw StateError('Invalid legacy receipt value.');
    if (raw.startsWith('[')) {
      final decoded = jsonDecode(raw);
      if (decoded is! List ||
          decoded.any((value) => value is! String || value.trim().isEmpty)) {
        throw StateError('Invalid legacy receipt path list.');
      }
      return decoded.cast<String>();
    }
    return [raw];
  }

  static String _safeName(String id, int position) =>
      '${sha256.convert(utf8.encode(jsonEncode([id, position])))}.bin';

  static Map<String, Object?> _financeValues(
      Map<String, Object?> source) {
    final copied = <String, Object?>{};
    for (final key in WaffraLegacyPreflight.allKeys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      copied[key] = value is List<String>
          ? List<String>.unmodifiable(value)
          : value;
    }
    return copied;
  }

  Future<WaffraReceiptStagingReport> stage() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted receipt staging is disabled by default.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final source = <String, Object?>{};
      for (final key in WaffraLegacyPreflight.allKeys) {
        if (prefs.containsKey(key)) source[key] = prefs.get(key);
      }
      final preflight = WaffraLegacyPreflight.inspect(source);
      if (!preflight.canStage) {
        throw StateError('Invalid original finance prevents receipt migration.');
      }

      final encrypted = await WaffraAtomicFinanceSnapshot(
        store: store, experimentalEnabled: true,
      ).read();
      if (encrypted.generation != 1 ||
          _canonicalJson(encrypted.values) !=
              _canonicalJson(_financeValues(source))) {
        throw StateError('Finance snapshot must match preflight before receipt staging.');
      }

      final roots = <String>[];
      for (final dir in trustedRoots) {
        if (!await dir.exists()) {
          throw StateError('Trusted local receipt directory not found.');
        }
        final canonical = await dir.resolveSymbolicLinks();
        if (canonical == Platform.pathSeparator) {
          throw StateError('Filesystem root cannot be a trusted receipt folder.');
        }
        roots.add(canonical.endsWith(Platform.pathSeparator)
            ? canonical : '$canonical${Platform.pathSeparator}');
      }

      final decoded = jsonDecode(source['entries'] as String? ?? '[]');
      if (decoded is! List) throw StateError('Invalid legacy entries array.');
      return store.transaction(() async {
        final oldEntries = await store.customSelect(
          'SELECT count(*) AS n FROM fresh_finance_entries',
        ).getSingle();
        if (oldEntries.read<int>('n') != 0) {
          throw StateError('Ledger projection already staged; no unsafe overwrite.');
        }
        await store.customStatement('''
CREATE TABLE IF NOT EXISTS $_receiptTable(
  entry_id TEXT NOT NULL REFERENCES fresh_finance_entries(entry_id)
    ON DELETE RESTRICT,
  position INTEGER NOT NULL CHECK(position >= 0),
  safe_name TEXT NOT NULL UNIQUE,
  content_sha256 TEXT NOT NULL,
  content_bytes INTEGER NOT NULL CHECK(content_bytes > 0),
  encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id,position)
)''');

        var copiedReceipts = 0;
        var copiedBytes = 0;
        var projectedIncome = 0;
        var projectedExpense = 0;

        for (final item in decoded) {
          if (item is! Map) throw StateError('Invalid ledger record.');
          final raw = Map<String, Object?>.from(item);
          final id = raw['id'], amount = raw['amount'], income = raw['income'];
          final title = raw['title'], category = raw['category'];
          final date = raw['date'];
          if (id is! String || id.isEmpty ||
              amount is! num ||
              !WaffraLegacyPreflight.canRepresentHalalas(amount) ||
              income is! bool ||
              title is! String || title.trim().isEmpty ||
              category is! String || category.trim().isEmpty ||
              date is! String || DateTime.tryParse(date) == null) {
            throw StateError('Cannot project incomplete financial transaction.');
          }
          final paths = _paths(raw['receiptPath']);
          if (paths.length > maxReceiptsPerEntry) {
            throw StateError('Too many receipt files to install safely.');
          }
          final amountMinor = (amount * 100).round();
          if (income) {
            projectedIncome += amountMinor;
          } else {
            projectedExpense += amountMinor;
          }
          await store.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
            [id, title, category, amountMinor, income ? 1 : 0,
             date, paths.length, jsonEncode(raw)],
          );

          for (var pos = 0; pos < paths.length; pos++) {
            final path = paths[pos];
            final file = File(path);
            if (!file.isAbsolute ||
                await FileSystemEntity.type(
                  path, followLinks: false,
                ) != FileSystemEntityType.file) {
              throw StateError('Receipt missing or unsafe.');
            }
            final canonical = await file.resolveSymbolicLinks();
            if (!roots.any((root) => canonical.startsWith(root))) {
              throw StateError('Receipt outside trusted storage.');
            }
            final before = await file.stat();
            if (before.size <= 0 || before.size > maxReceiptBytes) {
              throw StateError('Receipt size outside safe copy policy.');
            }
            final bytes = Uint8List.fromList(await file.readAsBytes());
            final after = await file.stat();
            if (after.size != before.size ||
                after.modified != before.modified ||
                bytes.length != before.size) {
              throw StateError('Receipt changed while copying.');
            }
            final digest = sha256.convert(bytes).toString();
            await store.customStatement(
              'INSERT INTO $_receiptTable(entry_id,position,safe_name,'
              'content_sha256,content_bytes,encrypted_blob) '
              'VALUES (?,?,?,?,?,?)',
              [id, pos, _safeName(id, pos), digest, bytes.length, bytes],
            );
            copiedReceipts++;
            copiedBytes += bytes.length;
          }
        }

        final saved = await store.customSelect(
          'SELECT count(*) AS n, '
          'COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0)'
          ' AS income_minor, '
          'COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0)'
          ' AS expense_minor FROM fresh_finance_entries',
        ).getSingle();
        final receiptRows = await store.customSelect(
          'SELECT content_sha256,content_bytes,encrypted_blob '
          'FROM $_receiptTable',
        ).get();
        if (saved.read<int>('n') != decoded.length ||
            saved.read<int>('income_minor') != projectedIncome ||
            saved.read<int>('expense_minor') != projectedExpense ||
            receiptRows.length != copiedReceipts) {
          throw StateError('Encrypted ledger projection parity failed.');
        }
        for (final row in receiptRows) {
          final bytes = row.read<Uint8List>('encrypted_blob');
          if (bytes.length != row.read<int>('content_bytes') ||
              sha256.convert(bytes).toString() !=
                  row.read<String>('content_sha256')) {
            throw StateError('Encrypted receipt readback checksum mismatch.');
          }
        }

        // Even a non-participating legacy writer cannot make us claim that
        // a mismatched source was migrated. Roll back this whole SQL tx.
        await prefs.reload();
        final afterFinance = <String, Object?>{};
        for (final key in WaffraLegacyPreflight.allKeys) {
          if (prefs.containsKey(key)) afterFinance[key] = prefs.get(key);
        }
        if (WaffraLegacyPreflight.inspect(afterFinance).sourceSha256 !=
            preflight.sourceSha256) {
          throw StateError('Legacy finance changed during encrypted receipt staging.');
        }
        return WaffraReceiptStagingReport(
          ledgerRecords: decoded.length,
          receiptBlobs: copiedReceipts,
          receiptBytes: copiedBytes,
          legacyFinanceDigest: preflight.sourceSha256,
        );
      });
    });
  }
}

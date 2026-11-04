import 'dart:convert';

import 'package:drift/drift.dart';

import '../waffra_sms_fx_review.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

/// Currency is always an integer number of halalas in encrypted SQLite.
/// This first repository iteration intentionally excludes receipt attachments:
/// the M25-M27 file lifecycle must be atomically coordinated before attachment
/// writes can be exposed to the running app.
class WaffraFreshLedgerEntry {
  const WaffraFreshLedgerEntry({
    required this.id,
    required this.title,
    required this.categorySnapshot,
    required this.amountMinor,
    required this.isIncome,
    required this.occurredIso,
    this.fxReview,
  });

  final String id;
  final String title;
  final String categorySnapshot;
  final int amountMinor;
  final bool isIncome;
  final String occurredIso;
  /// Optional user-approved original currency and FX evidence in the same
  /// SQLCipher row as the converted SAR amount (source_json).
  final WaffraSmsFxReview? fxReview;

  Map<String, Object?> toLegacyShape() => {
    'id': id,
    'title': title,
    'category': categorySnapshot,
    'amount': amountMinor / 100,
    'income': isIncome,
    'date': occurredIso,
    'receiptPath': null,
    if (fxReview != null)
      'waffra_fx_provenance_v1': fxReview!.toProvenanceJson(),
  };
}

class WaffraFreshLedgerTotals {
  const WaffraFreshLedgerTotals({
    required this.count,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int count;
  final int incomeMinor;
  final int expenseMinor;
}

/// Explicitly opt-in CRUD for the still DISCONNECTED new encrypted ledger.
/// Does not touch SharedPreferences, receipt files, the widget, or Firebase.
/// Operations require a v1 fresh vault initialized by M28. Do not connect
/// directly to app screens until a single-writer durable source selector exists.
class WaffraFreshLedgerRepository {
  const WaffraFreshLedgerRepository({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static void validateExperimentalEntry(WaffraFreshLedgerEntry entry) {
    if (entry.id.trim().isEmpty || entry.id.length > 256 ||
        entry.title.trim().isEmpty ||
        entry.categorySnapshot.trim().isEmpty ||
        entry.amountMinor < 0 ||
        entry.amountMinor > 9007199254740991 ||
        entry.occurredIso.length < 10 ||
        DateTime.tryParse(entry.occurredIso) == null) {
      throw ArgumentError('Invalid finance record; refusing encrypted write.');
    }
    final fx = entry.fxReview;
    if (fx != null) {
      // SAR-only totals must never sum unrelated foreign currency amounts.
      if (fx.originalCurrency == 'SAR' ||
          fx.convertedCurrency != 'SAR' ||
          fx.convertedMinor != entry.amountMinor ||
          fx.originalMinor <= 0 ||
          fx.rateTimestampUtc.isAfter(fx.userApprovedAtUtc.add(
            const Duration(hours: 1))) ||
          fx.userApprovedAtUtc.difference(fx.rateTimestampUtc) >
              WaffraSmsFxQuote.maxAge) {
        throw ArgumentError('Currency evidence does not match SAR ledger amount.');
      }
      WaffraSmsFxReview.fromProvenanceJson(fx.toProvenanceJson());
    }
  }

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted finance repository is disabled by default.');
    }
    final meta = await store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_meta'",
    ).get();
    if (meta.length != 1) {
      throw StateError('Fresh finance vault is not initialized.');
    }
    final revision = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (revision.length != 1 ||
        revision.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Unrecognized or incomplete finance vault.');
    }
    final shadow = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (shadow.read<int>('n') != 0) {
      throw StateError('Cannot mix fresh ledger with an import sandbox.');
    }
  }

  Future<void> add(WaffraFreshLedgerEntry entry) async {
    await _requireReady();
    validateExperimentalEntry(entry);
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_entries '
        '(entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
        [
          entry.id, entry.title, entry.categorySnapshot, entry.amountMinor,
          entry.isIncome ? 1 : 0, entry.occurredIso, 0,
          jsonEncode(entry.toLegacyShape()),
        ],
      );
    });
  }

  Future<void> replace(WaffraFreshLedgerEntry entry) async {
    await _requireReady();
    validateExperimentalEntry(entry);
    await store.transaction(() async {
      // Updating transaction attachment associations requires a separate
      // verified installer. Never discard an attached record's file metadata.
      final prior = await store.customSelect(
        'SELECT receipt_count,source_json FROM fresh_finance_entries WHERE entry_id = ?',
        variables: [Variable.withString(entry.id)],
      ).get();
      if (prior.length != 1) throw StateError('Entry does not exist.');
      if (prior.single.read<int>('receipt_count') != 0) {
        throw StateError('Attachment-bearing entry cannot be replaced here.');
      }
      final original = jsonDecode(prior.single.read<String>('source_json'));
      if (original is! Map<String, dynamic> ||
          original.containsKey('waffra_fx_provenance_v1') ||
          entry.fxReview != null) {
        throw StateError('FX edits need certified atomic provenance replacement.');
      }
      await store.customStatement(
        'UPDATE fresh_finance_entries SET title=?,category_snapshot=?,'
        'amount_minor=?,is_income=?,occurred_iso=?,source_json=? '
        'WHERE entry_id=?',
        [
          entry.title, entry.categorySnapshot, entry.amountMinor,
          entry.isIncome ? 1 : 0, entry.occurredIso,
          jsonEncode(entry.toLegacyShape()), entry.id,
        ],
      );
    });
  }

  Future<void> remove(String entryId) async {
    await _requireReady();
    if (entryId.trim().isEmpty) throw ArgumentError.value(entryId, 'entryId');
    await store.transaction(() async {
      final rows = await store.customSelect(
        'SELECT receipt_count,source_json FROM fresh_finance_entries WHERE entry_id = ?',
        variables: [Variable.withString(entryId)],
      ).get();
      if (rows.length != 1) throw StateError('Entry does not exist.');
      if (rows.single.read<int>('receipt_count') != 0) {
        throw StateError('Attachment-bearing entry must use safe receipt removal.');
      }
      final original = jsonDecode(rows.single.read<String>('source_json'));
      if (original is! Map<String, dynamic> ||
          original.containsKey('waffra_fx_provenance_v1')) {
        throw StateError('FX deletion requires encrypted Undo and backup parity.');
      }
      await store.customStatement(
        'DELETE FROM fresh_finance_entries WHERE entry_id = ?',
        [entryId],
      );
    });
  }

  Future<List<WaffraFreshLedgerEntry>> list() async {
    await _requireReady();
    final rows = await store.customSelect(
      'SELECT entry_id,title,category_snapshot,amount_minor,is_income,'
      'occurred_iso,source_json FROM fresh_finance_entries '
      'ORDER BY occurred_iso DESC,entry_id DESC',
    ).get();
    return List<WaffraFreshLedgerEntry>.unmodifiable(rows.map((row) {
      final record = jsonDecode(row.read<String>('source_json'));
      if (record is! Map<String, dynamic> ||
          record['id'] != row.read<String>('entry_id') ||
          record['amount'] != row.read<int>('amount_minor') / 100) {
        throw StateError('Encrypted entry amount/source mismatch.');
      }
      final rawFx = record['waffra_fx_provenance_v1'];
      WaffraSmsFxReview? fx;
      if (rawFx != null) {
        if (rawFx is! Map<String, dynamic>) {
          throw StateError('Malformed encrypted FX provenance.');
        }
        fx = WaffraSmsFxReview.fromProvenanceJson(rawFx);
      }
      final entry = WaffraFreshLedgerEntry(
        id: row.read<String>('entry_id'),
        title: row.read<String>('title'),
        categorySnapshot: row.read<String>('category_snapshot'),
        amountMinor: row.read<int>('amount_minor'),
        isIncome: row.read<int>('is_income') == 1,
        occurredIso: row.read<String>('occurred_iso'),
        fxReview: fx,
      );
      validateExperimentalEntry(entry);
      return entry;
    }));
  }

  Future<WaffraFreshLedgerTotals> totals() async {
    await _requireReady();
    final row = await store.customSelect('''
SELECT count(*) AS total,
COALESCE(SUM(CASE WHEN is_income=1 THEN amount_minor ELSE 0 END),0)
AS income_minor,
COALESCE(SUM(CASE WHEN is_income=0 THEN amount_minor ELSE 0 END),0)
AS expense_minor
FROM fresh_finance_entries
''').getSingle();
    return WaffraFreshLedgerTotals(
      count: row.read<int>('total'),
      incomeMinor: row.read<int>('income_minor'),
      expenseMinor: row.read<int>('expense_minor'),
    );
  }
}

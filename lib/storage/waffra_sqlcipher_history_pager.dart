import 'package:drift/drift.dart';

import 'waffra_account_context_read.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// A cursor must originate from the last row of a previously verified page.
/// It is ordered by (occurredIso DESC, entryId DESC); never by row insertion
/// order, which is unstable after an edit/restore.
class WaffraSqlcipherHistoryCursor {
  const WaffraSqlcipherHistoryCursor({
    required this.occurredIso,
    required this.entryId,
  });

  final String occurredIso;
  final String entryId;
}

class WaffraSqlcipherHistoryPage {
  const WaffraSqlcipherHistoryPage({
    required this.entries,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<WaffraAccountLedgerRow> entries;
  final bool hasMore;
  final WaffraSqlcipherHistoryCursor? nextCursor;
}

/// Read-only, database-level keyset pages on the *supplied* encrypted store.
/// Unlike WaffraFinancePeriodIndex.pageNewestFirst, this method never
/// materializes the full ledger in memory before returning a page.
///
/// Only a caller already holding the verified active SQLCipher finance
/// authority should supply [store]. This utility does NOT open databases,
/// create a finance source, assign an account, calculate balances or write
/// entries. The screen owner must discard its cursor when the verified ledger
/// generation or filters change. Cross-revision snapshots are not claimed.
abstract final class WaffraSqlcipherHistoryPager {
  static const int maxPageSize = 500;

  static Future<WaffraSqlcipherHistoryPage> load({
    required WaffraEncryptedStore store,
    int limit = 100,
    String? monthIso,
    String? accountId,
    bool? income,
    bool unassignedOnly = false,
    WaffraSqlcipherHistoryCursor? after,
  }) async {
    if (limit < 1 || limit > maxPageSize) {
      throw ArgumentError.value(limit, 'limit', 'Must be 1..500.');
    }
    if (monthIso != null &&
        !RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$').hasMatch(monthIso)) {
      throw ArgumentError.value(monthIso, 'monthIso');
    }
    if (unassignedOnly && accountId != null) {
      throw ArgumentError('Unassigned-only pages cannot select an account.');
    }
    if (accountId != null &&
        (accountId.trim().isEmpty || accountId.length > 256)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    if (after != null &&
        (after.entryId.trim().isEmpty ||
            after.entryId.length > 256 ||
            DateTime.tryParse(after.occurredIso) == null)) {
      throw ArgumentError.value(after, 'after', 'Invalid page cursor.');
    }

    await WaffraAccountsSchema.requireReady(store);
    // An unknown account must not masquerade as a verified empty account.
    // Archived accounts can still have immutable historical entries.
    if (accountId != null) {
      final found = await store.customSelect(
        "SELECT account_id FROM fresh_finance_money_accounts "
        "WHERE account_id=? AND currency='SAR'",
        variables: [Variable.withString(accountId)],
      ).get();
      if (found.length != 1) {
        throw StateError('Requested account is absent from encrypted source.');
      }
    }

    final clauses = <String>[];
    final variables = <Variable>[];
    if (monthIso != null) {
      final start = DateTime.parse(monthIso + '-01');
      final end = DateTime(start.year, start.month + 1, 1);
      final endMonth = end.year.toString().padLeft(4, '0') + '-' +
          end.month.toString().padLeft(2, '0') + '-01';
      clauses.add('e.occurred_iso>=? AND e.occurred_iso<?');
      variables.addAll([
        Variable.withString(monthIso + '-01'),
        Variable.withString(endMonth),
      ]);
    }
    if (unassignedOnly) {
      // All-time historical unassigned queue: SQLCipher applies the filter
      // before LIMIT, never load every old entry or use OFFSET for page N.
      clauses.add('l.account_id IS NULL');
    } else if (accountId != null) {
      clauses.add('l.account_id=?');
      variables.add(Variable.withString(accountId));
    }
    if (income != null) {
      clauses.add('e.is_income=?');
      variables.add(Variable.withInt(income ? 1 : 0));
    }
    if (after != null) {
      clauses.add(
        '(e.occurred_iso<? OR '
        '(e.occurred_iso=? AND e.entry_id<?))',
      );
      variables.addAll([
        Variable.withString(after.occurredIso),
        Variable.withString(after.occurredIso),
        Variable.withString(after.entryId),
      ]);
    }
    // Fetch one extra row to prove whether another page exists, without an
    // unbounded COUNT or OFFSET walk. Account associations are explicit only.
    variables.add(Variable.withInt(limit + 1));
    final query = '''
SELECT e.entry_id,e.title,e.amount_minor,e.is_income,e.occurred_iso,
 l.account_id,a.budget_id,a.amount_minor AS budget_allocated_minor
FROM fresh_finance_entries e
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id
-- Multibudget allocations must never create duplicate transaction cards
-- or break (occurred_iso,entry_id) keyset ordering across page boundaries.
LEFT JOIN (
 SELECT entry_id,
  CASE WHEN COUNT(*)=1 THEN MAX(budget_id) END AS budget_id,
  CASE WHEN COUNT(*)=1 THEN MAX(amount_minor) END AS amount_minor
 FROM fresh_finance_standalone_allocations GROUP BY entry_id
) a ON a.entry_id=e.entry_id
''' + (clauses.isEmpty ? '' : 'WHERE ' + clauses.join(' AND ') + '\n') + '''
ORDER BY e.occurred_iso DESC,e.entry_id DESC
LIMIT ?
''';
    final rows = await store.customSelect(query, variables: variables).get();
    final more = rows.length > limit;
    final page = List<WaffraAccountLedgerRow>.unmodifiable(
      rows.take(limit).map((r) => WaffraAccountLedgerRow(
        id: r.read<String>('entry_id'),
        title: r.read<String>('title'),
        occurredIso: r.read<String>('occurred_iso'),
        amountMinor: r.read<int>('amount_minor'),
        income: r.read<int>('is_income') == 1,
        accountId: r.readNullable<String>('account_id'),
        budgetId: r.readNullable<String>('budget_id'),
        budgetAllocatedMinor: r.readNullable<int>('budget_allocated_minor'),
      )),
    );
    final last = page.isEmpty ? null : page.last;
    return WaffraSqlcipherHistoryPage(
      entries: page,
      hasMore: more,
      nextCursor: more && last != null
          ? WaffraSqlcipherHistoryCursor(
              occurredIso: last.occurredIso, entryId: last.id)
          : null,
    );
  }
}

import 'package:drift/drift.dart';

import 'waffra_account_context_policy.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

class WaffraAccountLedgerRow {
  const WaffraAccountLedgerRow({
    required this.id, required this.title, required this.occurredIso,
    required this.amountMinor, required this.income,
    this.accountId, this.budgetId, this.budgetAllocatedMinor,
  });
  final String id, title, occurredIso;
  final int amountMinor;
  final bool income;
  final String? accountId, budgetId;
  final int? budgetAllocatedMinor;

  WaffraScopedEntry get scoped => WaffraScopedEntry(
    id: id, amountMinor: budgetAllocatedMinor ?? amountMinor, income: income,
    accountId: accountId, budgetId: budgetId,
  );
}

class WaffraAccountBudgetRow {
  const WaffraAccountBudgetRow({
    required this.id, required this.name, required this.usage,
  });
  final String id, name;
  final WaffraBudgetUse usage;
}

class WaffraAccountContextReadResult {
  const WaffraAccountContextReadResult(this.entries, this.budgets);
  final List<WaffraAccountLedgerRow> entries;
  final List<WaffraAccountBudgetRow> budgets;
}

/// Read-only SQLCipher projection. An entry with no association is visible in
/// All accounts, but contributes ZERO to the balances of individual accounts.
/// This query does not migrate or create any account link.
abstract final class WaffraAccountContextRead {
  static Future<WaffraAccountContextReadResult> load({
    required WaffraEncryptedStore store,
    required String monthIso,
    String? selectedAccountId,
  }) async {
    await WaffraAccountsSchema.requireReady(store);
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}$').hasMatch(monthIso) ||
        DateTime.tryParse(monthIso + '-01') == null) {
      throw ArgumentError('Invalid accounting month.');
    }
    final rows = await store.customSelect('''
SELECT e.entry_id, e.title, e.amount_minor, e.is_income, e.occurred_iso,
       l.account_id, a.budget_id, a.amount_minor AS budget_allocated_minor
FROM fresh_finance_entries e
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id
LEFT JOIN fresh_finance_standalone_allocations a ON a.entry_id=e.entry_id
ORDER BY e.occurred_iso DESC, e.entry_id DESC
''').get();
    final entries = List<WaffraAccountLedgerRow>.unmodifiable(rows.map((r) =>
      WaffraAccountLedgerRow(
        id: r.read<String>('entry_id'),
        title: r.read<String>('title'),
        occurredIso: r.read<String>('occurred_iso'),
        amountMinor: r.read<int>('amount_minor'),
        income: r.read<int>('is_income') == 1,
        accountId: r.readNullable<String>('account_id'),
        budgetId: r.readNullable<String>('budget_id'),
        budgetAllocatedMinor: r.readNullable<int>('budget_allocated_minor'),
      ),
    ));
    final budgets = await store.customSelect('''
SELECT budget_id, name, monthly_limit_minor
FROM fresh_finance_standalone_budgets
WHERE archived_at_iso IS NULL
ORDER BY name, budget_id
''').get();
    final monthEntries = entries.where((row) =>
      row.occurredIso.startsWith(monthIso + '-')).map((row) => row.scoped);
    final monthly = monthEntries.toList(growable: false);
    final summed = List<WaffraAccountBudgetRow>.unmodifiable(
      budgets.map((row) {
        final id = row.read<String>('budget_id');
        return WaffraAccountBudgetRow(
          id: id, name: row.read<String>('name'),
          usage: WaffraAccountContextPolicy.budget(
            entries: monthly, budgetId: id,
            limitMinor: row.read<int>('monthly_limit_minor'),
            selectedAccountId: selectedAccountId,
          ),
        );
      }),
    );
    return WaffraAccountContextReadResult(entries, summed);
  }

  static Future<int> attachPreviouslyUnassigned({
    required WaffraEncryptedStore store,
    required String entryId,
    required String accountId,
    required String confirmedIso,
    required bool userConfirmed,
  }) async {
    await WaffraAccountsSchema.requireReady(store);
    if (!userConfirmed || entryId.trim().isEmpty ||
        accountId.trim().isEmpty ||
        DateTime.tryParse(confirmedIso) == null) {
      throw StateError('Account attachment requires explicit confirmation.');
    }
    return store.transaction(() async {
      final matching = await store.customSelect('''
SELECT entry_id FROM fresh_finance_entries WHERE entry_id=?
''', variables: [Variable.withString(entryId)]).get();
      final account = await store.customSelect('''
SELECT account_id FROM fresh_finance_money_accounts
WHERE account_id=? AND archived=0 AND currency='SAR'
''', variables: [Variable.withString(accountId)]).get();
      if (matching.length != 1 || account.length != 1) {
        throw StateError('Ledger entry or active account is missing.');
      }
      // INSERT .. SELECT WHERE NOT EXISTS is a single SQL decision, so
      // repeated confirmations cannot increase balance a second time.
      await store.customStatement('''
INSERT INTO fresh_finance_account_entry_links
 (entry_id,account_id,confirmed_iso)
SELECT ?,?,? WHERE NOT EXISTS (
 SELECT 1 FROM fresh_finance_account_entry_links WHERE entry_id=?
)
''', [entryId, accountId, confirmedIso, entryId]);
      final row = await store.customSelect('''
SELECT account_id FROM fresh_finance_account_entry_links WHERE entry_id=?
''', variables: [Variable.withString(entryId)]).getSingle();
      if (row.read<String>('account_id') != accountId) {
        throw StateError('Transaction is already assigned to another account.');
      }
      return 1;
    });
  }
}

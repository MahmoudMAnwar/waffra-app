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

class WaffraAccountGoalSummary {
 const WaffraAccountGoalSummary({
  required this.id,required this.name,required this.totalSavedMinor,
  required this.selectedAccountNetMinor,
 });
 final String id,name;
 final int totalSavedMinor,selectedAccountNetMinor;
}

class WaffraAccountContextReadResult {
 const WaffraAccountContextReadResult(this.entries,this.budgets,
  {this.goals=const <WaffraAccountGoalSummary>[]});
 final List<WaffraAccountLedgerRow> entries;
 final List<WaffraAccountBudgetRow> budgets;
 final List<WaffraAccountGoalSummary> goals;
}

/// Read-only SQLCipher projection. An entry with no association is visible in
/// All accounts, but contributes ZERO to the balances of individual accounts.
/// This query does not migrate or create any account link.
abstract final class WaffraAccountContextRead {
  static String _nextMonthIso(String monthIso){
    final date=DateTime.parse(monthIso+'-01');
    final next=DateTime(date.year,date.month+1,1);
    return next.year.toString().padLeft(4,'0')+'-'+
      next.month.toString().padLeft(2,'0')+'-01';
  }

  static Future<WaffraAccountContextReadResult> load({
    required WaffraEncryptedStore store,
    required String monthIso,
    String? selectedAccountId,
    bool summaryOnly=false,
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
WHERE (?=0 OR (e.occurred_iso>=? AND e.occurred_iso<?))
ORDER BY e.occurred_iso DESC, e.entry_id DESC
''',variables:[
 // Legacy callers retain all history; summaryOnly pages scan this month.
 Variable.withInt(summaryOnly?0:1),
 Variable.withString(monthIso+'-01'),
 Variable.withString(_nextMonthIso(monthIso)),
]).get();
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
    // A goal is its own savings wallet. Display the overall saved total
    // independently of the selected account contribution. These are read
    // projections only; viewing a goal never debits a bank.
    final goalRows=await store.customSelect('''
SELECT g.goal_id,g.name,g.saved_minor,
 COALESCE((SELECT SUM(CASE
  WHEN m.kind='fund' THEN m.amount_minor
  WHEN m.kind='release' THEN -m.amount_minor ELSE 0 END)
 FROM fresh_finance_goal_account_sources s
 JOIN fresh_finance_goal_wallet_movements m ON m.movement_id=s.movement_id
 WHERE m.goal_id=g.goal_id AND s.account_id=?),0) AS own_minor
FROM fresh_finance_goals g
ORDER BY g.name,g.goal_id
''',variables:[Variable.withString(selectedAccountId??'')]).get();
    final goals=List<WaffraAccountGoalSummary>.unmodifiable(
      goalRows.map((row)=>WaffraAccountGoalSummary(
       id:row.read<String>('goal_id'),
       name:row.read<String>('name'),
       totalSavedMinor:row.read<int>('saved_minor'),
       selectedAccountNetMinor:row.read<int>('own_minor'),
      )));
    return WaffraAccountContextReadResult(entries,summed,goals:goals);
  }

  /// M681: preview imported accountless entries without changing money.
  static Future<({int count,int netMinor})> unassignedSummary({
    required WaffraEncryptedStore store,
  }) async {
    await WaffraAccountsSchema.requireReady(store);
    final row=await store.customSelect('''
SELECT COUNT(*) AS entry_count,
 COALESCE(SUM(CASE WHEN e.is_income=1 THEN e.amount_minor
 ELSE -e.amount_minor END),0) AS net_minor
FROM fresh_finance_entries e
WHERE NOT EXISTS (
 SELECT 1 FROM fresh_finance_account_entry_links l
 WHERE l.entry_id=e.entry_id)
''').getSingle();
    return (count:row.read<int>('entry_count'),
      netMinor:row.read<int>('net_minor'));
  }

  /// M684: bounded SQLCipher monthly projection; the existing full-history
  /// reconciliation contract of load() is unchanged.
  static Future<List<WaffraAccountLedgerRow>> loadMonthEntries({
    required WaffraEncryptedStore store,
    required String monthIso,
    String? selectedAccountId,
    int limit=100,
    int offset=0,
  }) async {
    await WaffraAccountsSchema.requireReady(store);
    if(!RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$').hasMatch(monthIso) ||
       limit<1 || limit>500 || offset<0){
      throw ArgumentError('Invalid bounded accounting query.');
    }
    final from=DateTime.parse('$monthIso-01');
    final until=DateTime(from.year,from.month+1,1);
    final next=until.year.toString().padLeft(4,'0')+'-'+
      until.month.toString().padLeft(2,'0')+'-01';
    final rows=await store.customSelect('''
SELECT e.entry_id,e.title,e.amount_minor,e.is_income,e.occurred_iso,
 l.account_id,a.budget_id,a.amount_minor AS budget_allocated_minor
FROM fresh_finance_entries e
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id
LEFT JOIN fresh_finance_standalone_allocations a ON a.entry_id=e.entry_id
WHERE e.occurred_iso>=? AND e.occurred_iso<?
 '''+(selectedAccountId==null?'':'AND l.account_id=?')+'''
ORDER BY e.occurred_iso DESC,e.entry_id DESC
LIMIT ? OFFSET ?
''',variables:[
 Variable.withString(monthIso+'-01'),
 Variable.withString(next),
 if(selectedAccountId!=null)Variable.withString(selectedAccountId),
 Variable.withInt(limit),Variable.withInt(offset),
 ]).get();
    return List<WaffraAccountLedgerRow>.unmodifiable(rows.map((r)=>
      WaffraAccountLedgerRow(
        id:r.read<String>('entry_id'),
        title:r.read<String>('title'),
        occurredIso:r.read<String>('occurred_iso'),
        amountMinor:r.read<int>('amount_minor'),
        income:r.read<int>('is_income')==1,
        accountId:r.readNullable<String>('account_id'),
        budgetId:r.readNullable<String>('budget_id'),
        budgetAllocatedMinor:r.readNullable<int>('budget_allocated_minor'),
      )));
  }

  /// M681: original accountless history, not only current month. Paged and
  /// read-only until the user approves a single verified account link.
  static Future<List<WaffraAccountLedgerRow>> loadUnassignedEntries({
    required WaffraEncryptedStore store,int limit=50,int offset=0,
  }) async {
    await WaffraAccountsSchema.requireReady(store);
    if(limit<1||limit>500||offset<0){
      throw ArgumentError('Invalid unassigned ledger page.');
    }
    final rows=await store.customSelect('''
SELECT e.entry_id,e.title,e.amount_minor,e.is_income,e.occurred_iso
FROM fresh_finance_entries e
WHERE NOT EXISTS (
 SELECT 1 FROM fresh_finance_account_entry_links l WHERE l.entry_id=e.entry_id
)
ORDER BY e.occurred_iso DESC,e.entry_id DESC
LIMIT ? OFFSET ?
''',variables:[Variable.withInt(limit),Variable.withInt(offset)]).get();
    return List<WaffraAccountLedgerRow>.unmodifiable(rows.map((r)=>
     WaffraAccountLedgerRow(id:r.read<String>('entry_id'),
      title:r.read<String>('title'),
      occurredIso:r.read<String>('occurred_iso'),
      amountMinor:r.read<int>('amount_minor'),
      income:r.read<int>('is_income')==1)));
  }

  static Future<int> attachPreviouslyUnassigned({
    required WaffraEncryptedStore store,
    required String entryId,
    required String accountId,
    required String confirmedIso,
    required bool userConfirmed,
    bool openingExcludesHistory=false,
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
SELECT account_id,opening_minor FROM fresh_finance_money_accounts
WHERE account_id=? AND archived=0 AND currency='SAR'
''', variables: [Variable.withString(accountId)]).get();
      if (matching.length != 1 || account.length != 1) {
        throw StateError('Ledger entry or active account is missing.');
      }
      // A pre-existing opening balance may already include these historic
      // entries; attaching them without reconciliation would double count.
      if(account.single.read<int>('opening_minor')!=0 &&
         !openingExcludesHistory){
        // No inference is safe: the opening could already include this
        // transaction. User must independently confirm it does not.
        throw StateError(
         'Confirm historical entry is excluded from account opening balance.');
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

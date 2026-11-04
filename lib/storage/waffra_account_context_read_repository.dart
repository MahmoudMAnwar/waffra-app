import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// Account-aware *read* projections from one verified SQLCipher finance source.
/// A header account is presentation context, never an implicit posting target.
class WaffraAccountBudgetView {
  const WaffraAccountBudgetView({
    required this.budgetId, required this.monthlyLimitMinor,
    required this.allAccountsSpentMinor, required this.selectedAccountSpentMinor,
    required this.alertPercent,
  });
  final String budgetId;
  final int monthlyLimitMinor, allAccountsSpentMinor, selectedAccountSpentMinor;
  final int alertPercent;
  bool get alertReached =>
      allAccountsSpentMinor * 100 >= monthlyLimitMinor * alertPercent;
}

class WaffraAccountGoalView {
  const WaffraAccountGoalView({
    required this.goalId,required this.totalSavedMinor,
    required this.selectedAccountContributedMinor,
    required this.allAttributedContributionsMinor,
  });
  final String goalId;
  /// Current goal wallet total, including funding from all sources.
  final int totalSavedMinor;
  /// Lifetime confirmed contributions traceable to the selected account.
  /// Releases are not silently redistributed between source accounts.
  final int selectedAccountContributedMinor,allAttributedContributionsMinor;
}

class WaffraUnassignedMoneyEntry {
  const WaffraUnassignedMoneyEntry(this.id,this.title,this.amountMinor,
      this.income,this.occurredIso);
  final String id,title,occurredIso;
  final int amountMinor;
  final bool income;
}

/// Only accesses typed, version-checked encrypted tables. UI must obtain
/// this repository through the verified account authority/source lock.
/// It NEVER initializes SQLCipher, writes money, or guesses old account links.
class WaffraAccountContextReadRepository {
  const WaffraAccountContextReadRepository({
    required this.db, this.experimentalEnabled=false,
  });
  final WaffraEncryptedStore db;
  final bool experimentalEnabled;

  Future<void> _ready() async {
    if(!experimentalEnabled) {
      throw StateError('Account-aware views need certified SQLCipher source.');
    }
    await WaffraAccountsSchema.requireReady(db);
    await WaffraFreshFinanceDomainSchema.requireReady(db);
  }
  static void _id(String value) {
    if(value.trim().isEmpty || value.length>128) {
      throw ArgumentError('Invalid account or domain identifier.');
    }
  }

  /// One budget can be funded by cash and many banks. The spending threshold
  /// uses ALL explicitly allocated expense entries, never header-specific sums.
  Future<WaffraAccountBudgetView> budget({
    required String budgetId, required DateTime month, String? accountId,
  }) async {
    await _ready();
    _id(budgetId);
    if(accountId!=null)_id(accountId);
    final budget=await db.customSelect(
      'SELECT monthly_limit_minor,alert_percent '
      'FROM fresh_finance_standalone_budgets WHERE budget_id=?',
      variables:[Variable.withString(budgetId)],
    ).get();
    if(budget.length!=1)throw StateError('Standalone budget not found.');
    final monthKey='${month.year.toString().padLeft(4,'0')}-'
      '${month.month.toString().padLeft(2,'0')}';
    final spent=await db.customSelect('''
SELECT COALESCE(SUM(a.amount_minor),0) AS total_minor,
 COALESCE(SUM(CASE WHEN l.account_id=?
   THEN a.amount_minor ELSE 0 END),0) AS selected_minor
FROM fresh_finance_standalone_allocations a
JOIN fresh_finance_entries e ON e.entry_id=a.entry_id
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=a.entry_id
WHERE a.budget_id=? AND e.is_income=0
 AND substr(e.occurred_iso,1,7)=?
''',variables:[
      Variable.withString(accountId??''),
      Variable.withString(budgetId),Variable.withString(monthKey),
    ]).getSingle();
    return WaffraAccountBudgetView(
      budgetId:budgetId,
      monthlyLimitMinor:budget.single.read<int>('monthly_limit_minor'),
      allAccountsSpentMinor:spent.read<int>('total_minor'),
      selectedAccountSpentMinor:spent.read<int>('selected_minor'),
      alertPercent:budget.single.read<int>('alert_percent'),
    );
  }

  /// Existing wallet balance remains independent of the current header.
  /// Only explicitly entry-linked funding movements count as known sources.
  /// Unknown-source contributions never get attributed to the open account.
  Future<WaffraAccountGoalView> goal({
    required String goalId, String? accountId,
  }) async {
    await _ready();
    _id(goalId);
    if(accountId!=null)_id(accountId);
    final goals=await db.customSelect(
      'SELECT saved_minor FROM fresh_finance_goals WHERE goal_id=?',
      variables:[Variable.withString(goalId)],
    ).get();
    if(goals.length!=1)throw StateError('Goal not found.');
    final contribution=await db.customSelect('''
SELECT COALESCE(SUM(CASE WHEN l.account_id IS NOT NULL
 THEN m.amount_minor ELSE 0 END),0) AS attributed_minor,
 COALESCE(SUM(CASE WHEN l.account_id=?
 THEN m.amount_minor ELSE 0 END),0) AS selected_minor
FROM fresh_finance_goal_wallet_movements m
LEFT JOIN fresh_finance_account_entry_links l
 ON l.entry_id=m.linked_entry_id
WHERE m.goal_id=? AND m.kind='fund'
''',variables:[
      Variable.withString(accountId??''),Variable.withString(goalId),
    ]).getSingle();
    return WaffraAccountGoalView(
      goalId:goalId,totalSavedMinor:goals.single.read<int>('saved_minor'),
      selectedAccountContributedMinor:contribution.read<int>('selected_minor'),
      allAttributedContributionsMinor:contribution.read<int>('attributed_minor'),
    );
  }

  /// "All accounts" includes entries that have no account link.
  /// "Without account" is an explicit subset; neither screen changes balances.
  Future<List<WaffraUnassignedMoneyEntry>> withoutAccount({int limit=100}) async {
    await _ready();
    if(limit<1 || limit>500)throw ArgumentError('Invalid page size.');
    final rows=await db.customSelect('''
SELECT e.entry_id,e.title,e.amount_minor,e.is_income,e.occurred_iso
FROM fresh_finance_entries e
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id
WHERE l.entry_id IS NULL
ORDER BY e.occurred_iso DESC,e.entry_id DESC LIMIT ?
''',variables:[Variable.withInt(limit)]).get();
    return List<WaffraUnassignedMoneyEntry>.unmodifiable(rows.map((r)=>
      WaffraUnassignedMoneyEntry(
        r.read<String>('entry_id'),r.read<String>('title'),
        r.read<int>('amount_minor'),r.read<int>('is_income')==1,
        r.read<String>('occurred_iso'),
      )));
  }
}

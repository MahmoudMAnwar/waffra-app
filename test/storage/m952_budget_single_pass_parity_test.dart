import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';

/// M952 axes 1 and 3: 10,000 synthetic postings / 120 budgets. Compare the
/// new O(entries + budgets) projection to the original per-budget policy.
/// Data are local, deterministic and read-only; no user finance is accessed.
void main() {
  test('M952 10k entries / 120 budgets produce identical exact-halala totals',
      () {
    final budgets = <String, int>{
      for (var index = 0; index < 120; index++)
        'budget-$index': 150000 + index * 101,
    };
    final entries = List<WaffraScopedEntry>.generate(10000, (index) {
      final id = 'synthetic-$index';
      return WaffraScopedEntry(
        id: id,
        amountMinor: 100 + index % 73,
        income: index % 17 == 0,
        budgetId: index % 4 == 0
            ? null
            : 'budget-${index % budgets.length}',
        accountId: index % 3 == 0
            ? null
            : (index % 3 == 1 ? 'bank-a' : 'bank-b'),
      );
    }, growable: false);

    final chrono = Stopwatch()..start();
    final projected = WaffraAccountContextPolicy.budgetSummaries(
      entries: entries,
      limitsMinor: budgets,
      selectedAccountId: 'bank-a',
    );
    chrono.stop();
    final original = Stopwatch()..start();
    for (final budget in budgets.entries) {
      final before = WaffraAccountContextPolicy.budget(
        entries: entries,
        budgetId: budget.key,
        limitMinor: budget.value,
        selectedAccountId: 'bank-a',
      );
      final after = projected[budget.key]!;
      expect(after.globalSpentMinor, before.globalSpentMinor,
          reason: budget.key);
      expect(after.selectedAccountSpentMinor,
          before.selectedAccountSpentMinor, reason: budget.key);
      expect(after.limitMinor, before.limitMinor, reason: budget.key);
      expect(after.reached(30), before.reached(30),
          reason: budget.key);
    }
    original.stop();
    // The measurements are diagnostic host elapsed times, not guaranteed
    // speed on an owner's Android phone.
    // ignore: avoid_print
    print('M952 10k/120 pure budget summary: one pass '
        '${chrono.elapsedMicroseconds} us, baseline '
        '${original.elapsedMicroseconds} us');
    expect(projected.length, 120);
    expect(() => projected.clear(), throwsUnsupportedError);
    // Same unmodified source objects; projecting cannot debit any account.
    expect(entries.length, 10000);
  });

  test('M952 unassigned expense contributes only to global budget totals', () {
    const rows = <WaffraScopedEntry>[
      WaffraScopedEntry(id: 'unassigned',amountMinor: 125,income: false,
          budgetId: 'food'),
      WaffraScopedEntry(id: 'a',amountMinor: 251,income: false,
          budgetId: 'food',accountId: 'bank-a'),
      WaffraScopedEntry(id: 'b',amountMinor: 450,income: false,
          budgetId: 'food',accountId: 'bank-b'),
      WaffraScopedEntry(id: 'income',amountMinor: 900,income: true,
          budgetId: 'food',accountId: 'bank-a'),
      WaffraScopedEntry(id: 'not-budgeted',amountMinor: 88,income: false),
    ];
    final withAccount = WaffraAccountContextPolicy.budgetSummaries(
      entries: rows,limitsMinor: {'food': 1000, 'other': 400},
      selectedAccountId: 'bank-a',
    );
    expect(withAccount['food']!.globalSpentMinor, 826);
    expect(withAccount['food']!.selectedAccountSpentMinor, 251);
    expect(withAccount['other']!.globalSpentMinor, 0);
    expect(withAccount['other']!.selectedAccountSpentMinor, 0);
    expect(withAccount['food']!.reached(82), true);
    expect(withAccount['food']!.reached(83), false);
    final all = WaffraAccountContextPolicy.budgetSummaries(
      entries: rows,limitsMinor: {'food': 1000},
    );
    expect(all['food']!.globalSpentMinor, 826);
    expect(all['food']!.selectedAccountSpentMinor, 0);
  });

  test('M952 invalid known budget allocation or limit fails closed', () {
    expect(() => WaffraAccountContextPolicy.budgetSummaries(
        entries: const <WaffraScopedEntry>[],
        limitsMinor: {'bad': 0}), throwsArgumentError);
    expect(() => WaffraAccountContextPolicy.budgetSummaries(
        entries: const [
          WaffraScopedEntry(id: 'negative',amountMinor: -1,
            income: false,budgetId: 'food'),
        ],
        limitsMinor: {'food': 1000}), throwsStateError);
    // The original policy ignores unknown budget rows and income postings,
    // so the optimized summary must preserve those two safe exclusions.
    final guarded = WaffraAccountContextPolicy.budgetSummaries(
      entries: const [
        WaffraScopedEntry(id: 'unknown',amountMinor: -1,
          income: false,budgetId: 'inactive'),
        WaffraScopedEntry(id: 'refund',amountMinor: -1,
          income: true,budgetId: 'food'),
      ],
      limitsMinor: {'food': 1000});
    expect(guarded['food']!.globalSpentMinor, 0);
  });
}

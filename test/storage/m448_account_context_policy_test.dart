import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';

void main() {
  const food = 'food', rajhi = 'rajhi', cash = 'cash';
  const entries = <WaffraScopedEntry>[
    WaffraScopedEntry(id: '1', amountMinor: 20000, income: false,
        accountId: rajhi, budgetId: food),
    WaffraScopedEntry(id: '2', amountMinor: 10000, income: false,
        accountId: cash, budgetId: food),
    WaffraScopedEntry(id: '3', amountMinor: 5000, income: false,
        budgetId: food),
    WaffraScopedEntry(id: '4', amountMinor: 30000, income: true,
        accountId: rajhi),
  ];

  test('all accounts contains unassigned; selected balances exclude it', () {
    expect(entries.where((e) => WaffraAccountContextPolicy.visible(
        e, WaffraAccountView.all)).length, 4);
    expect(entries.where((e) => WaffraAccountContextPolicy.visible(
        e, WaffraAccountView.unassigned)).map((e) => e.id), ['3']);
    expect(entries.where((e) => WaffraAccountContextPolicy.visible(
        e, WaffraAccountView.selected, selectedAccountId: rajhi))
        .map((e) => e.id), ['1', '4']);
    expect(entries.map((e) =>
        WaffraAccountContextPolicy.balanceDelta(e, cash))
        .reduce((a, b) => a + b), -10000);
  });

  test('budget threshold and global use ignore the current header', () {
    final usage = WaffraAccountContextPolicy.budget(
      entries: entries, budgetId: food, limitMinor: 100000,
      selectedAccountId: rajhi,
    );
    expect(usage.selectedAccountSpentMinor, 20000);
    expect(usage.globalSpentMinor, 35000);
    expect(usage.reached(35), isTrue);
    expect(usage.reached(36), isFalse);
  });

  test('goal net contribution is source specific and not twice debited', () {
    const source = <WaffraGoalSource>[
      WaffraGoalSource(movementId: 'a', accountId: rajhi,
          amountMinor: 30000, isRelease: false),
      WaffraGoalSource(movementId: 'b', accountId: cash,
          amountMinor: 70000, isRelease: false),
      WaffraGoalSource(movementId: 'c', accountId: rajhi,
          amountMinor: 5000, isRelease: true),
    ];
    expect(WaffraAccountContextPolicy.goalContribution(source, rajhi), 25000);
    expect(WaffraAccountContextPolicy.goalContribution(source, cash), 70000);
  });

  test('recurring one-time override preserves future default', () {
    final once = WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId: rajhi, chosenAccountId: cash,
      change: WaffraRecurringAccountChange.thisPaymentOnly);
    expect(once.paymentAccountId, cash);
    expect(once.nextDefaultAccountId, rajhi);
    final future = WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId: rajhi, chosenAccountId: cash,
      change: WaffraRecurringAccountChange.futurePayments);
    expect(future.nextDefaultAccountId, cash);
  });

  test('SMS requires exact unique verified suffix, never header', () {
    final verified = <String, String>{rajhi: '١٢٣٤', cash: '9999'};
    final outgoing = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: '1234', destinationSuffix: null, incoming: false,
      classifiedIncomeOrExpense: true, verifiedSuffixByAccount: verified);
    expect(outgoing.accountId, rajhi);
    expect(outgoing.confident, true);
    final unknown = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: null, destinationSuffix: null, incoming: false,
      classifiedIncomeOrExpense: true, verifiedSuffixByAccount: verified);
    expect(unknown.accountId, isNull);
    final ambiguous = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: '1234', destinationSuffix: null, incoming: false,
      classifiedIncomeOrExpense: true,
      verifiedSuffixByAccount: {rajhi: '1234', 'another': '١٢٣٤'});
    expect(ambiguous.confident, false);
    final internal = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: '1234', destinationSuffix: null, incoming: false,
      classifiedIncomeOrExpense: false, verifiedSuffixByAccount: verified);
    expect(internal.accountId, isNull);
  });
}

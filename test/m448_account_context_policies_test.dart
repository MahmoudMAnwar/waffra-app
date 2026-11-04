import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_context_policies.dart';
import 'package:waffra/storage/waffra_account_context_read_repository.dart';

void main() {
  test('M448 SMS strong bank evidence beats unrelated cash header',(){
    final match=WaffraBankSmsAccountPolicy.resolve(
      smsText:'Al Rajhi debit transaction from account **1234 SAR 200',
      currentlyOpenAccountId:'cash',
      knownAccounts:const [
        WaffraBankAccountEvidence(
          accountId:'rajhi',bankMarker:'Al Rajhi',lastFour:'1234'),
        WaffraBankAccountEvidence(
          accountId:'cash',bankMarker:'Cash',lastFour:'9999'),
      ],
    );
    expect(match.confidentlyMatched,isTrue);
    expect(match.suggestedAccountId,'rajhi');
  });

  test('M448 SMS unknown or ambiguous stays without account',(){
    const accounts=[
      WaffraBankAccountEvidence(
        accountId:'a',bankMarker:'Al Rajhi',lastFour:'1234'),
      WaffraBankAccountEvidence(
        accountId:'b',bankMarker:'Al Rajhi',lastFour:'1234'),
    ];
    expect(WaffraBankSmsAccountPolicy.resolve(
      smsText:'SAR 200 payment',knownAccounts:accounts,
      currentlyOpenAccountId:'a').suggestedAccountId,isNull);
    expect(WaffraBankSmsAccountPolicy.resolve(
      smsText:'Al Rajhi **1234 debit',knownAccounts:accounts,
      currentlyOpenAccountId:'a').suggestedAccountId,isNull);
  });

  test('M448 recurring one-time account choice preserves saved default',(){
    final choice=WaffraRecurringAccountPolicy.decide(
      storedDefaultAccountId:'rajhi',
      explicitlyChosenAccountId:'cash',
      scope:WaffraRecurringAccountChangeScope.thisPaymentOnly,
      userConfirmed:true,
    );
    expect(choice.paymentAccountId,'cash');
    expect(choice.nextDefaultAccountId,'rajhi');
    final stored=WaffraRecurringAccountPolicy.withNextDefault(
      {'id':'internet','reminderEnabled':false,'active':true},choice);
    expect(stored['defaultAccountId'],'rajhi');
    expect(stored['reminderEnabled'],false);
    expect(stored['active'],true);
  });

  test('M448 recurring future choice changes only future default',(){
    final choice=WaffraRecurringAccountPolicy.decide(
      storedDefaultAccountId:'rajhi',
      explicitlyChosenAccountId:'cash',
      scope:WaffraRecurringAccountChangeScope.futurePayments,
      userConfirmed:true,
    );
    expect(choice.paymentAccountId,'cash');
    expect(choice.nextDefaultAccountId,'cash');
    final unchanged=WaffraRecurringAccountPolicy.decide(
      storedDefaultAccountId:'rajhi',
      explicitlyChosenAccountId:null,
      scope:WaffraRecurringAccountChangeScope.thisPaymentOnly,
      userConfirmed:true,
    );
    expect(unchanged.paymentAccountId,'rajhi');
    expect(()=>WaffraRecurringAccountPolicy.decide(
      storedDefaultAccountId:'rajhi',
      explicitlyChosenAccountId:'cash',
      scope:WaffraRecurringAccountChangeScope.futurePayments,
      userConfirmed:false),throwsStateError);
  });

  test('M448 wallet funded dues never debit the bank a second time',(){
    expect(WaffraGoalAccountDebitPolicy.cashDebitMinor(
      totalDueMinor:20000,goalWalletPaidMinor:15000),5000);
    expect(WaffraGoalAccountDebitPolicy.cashDebitMinor(
      totalDueMinor:20000,goalWalletPaidMinor:20000),0);
    expect(()=>WaffraGoalAccountDebitPolicy.cashDebitMinor(
      totalDueMinor:100,goalWalletPaidMinor:101),throwsArgumentError);
  });

  test('M448 budget warning uses global total not selected account',(){
    const view=WaffraAccountBudgetView(
      budgetId:'food',monthlyLimitMinor:100000,
      allAccountsSpentMinor:30000,selectedAccountSpentMinor:20000,
      alertPercent:30,
    );
    expect(view.selectedAccountSpentMinor,20000);
    expect(view.allAccountsSpentMinor,30000);
    expect(view.alertReached,isTrue);
  });

  test('M448 goal wallet shows independent total and known bank part',(){
    const view=WaffraAccountGoalView(
      goalId:'travel',totalSavedMinor:100000,
      selectedAccountContributedMinor:30000,
      allAttributedContributionsMinor:30000,
    );
    expect(view.totalSavedMinor,100000);
    expect(view.selectedAccountContributedMinor,30000);
  });
}

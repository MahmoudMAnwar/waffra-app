import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';
import 'package:waffra/waffra_recurring_policy.dart';

/// M950: cross-policy DECISIONS not previously asserted as combined cases.
/// Host-side synthetic data only. They cannot verify live Android SMS.
void main() {
  WaffraSmsAccountDecision choose({
    String? source, String? destination, bool incoming=false,
    bool classified=true, Map<String,String> verified=const {'bank':'1234'},
  }) => WaffraAccountContextPolicy.matchBankSms(
    sourceSuffix:source, destinationSuffix:destination,
    incoming:incoming, classifiedIncomeOrExpense:classified,
    verifiedSuffixByAccount:verified);

  WaffraScopedEntry entry(String id,int minor,{String? account,
    String? budget,bool income=false})=>WaffraScopedEntry(
      id:id,amountMinor:minor,income:income,accountId:account,budgetId:budget);
  WaffraGoalSource movement(String id,String account,int minor,
    {bool release=false})=>WaffraGoalSource(
      movementId:id,accountId:account,amountMinor:minor,isRelease:release);

  test('M950-P01 incoming verified Arabic destination digits map to one bank',(){
    final match=choose(source:'9999',destination:'١٢٣٤',incoming:true);
    expect(match.accountId,'bank');
    expect(match.confident,true);
  });
  test('M950-P02 outgoing Persian source digits map to Arabic verified suffix',(){
    final match=choose(source:'۱۲۳۴',destination:'9999',verified:{
      'bank':'١٢٣٤','cash':'5678',
    });
    expect(match.accountId,'bank');
    expect(match.confident,true);
  });
  test('M950-P03 incoming ignores matching source and requires verified destination',(){
    final match=choose(source:'1234',destination:'5678',incoming:true);
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P04 outgoing ignores matching destination when source mismatches',(){
    final match=choose(source:'5678',destination:'1234',incoming:false);
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P05 two accounts with suffixes in different numeral scripts are ambiguous',(){
    final match=choose(source:'1234',verified:{
      'bank':'١٢٣٤','wallet':'۱۲۳۴',
    });
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P06 three-digit suffix cannot select verified financial account',(){
    final match=choose(source:'234');
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P07 five-digit source is never truncated or guessed',(){
    final match=choose(source:'01234');
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P08 transfer or excluded classification blocks even exact verified SMS',(){
    final match=choose(source:'1234',classified:false);
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P09 invalid saved suffix on another bank does not poison unique match',(){
    final match=choose(source:'1234',verified:{
      'bank':'1234','invalid':'12AB','other':'9999',
    });
    expect(match.accountId,'bank');
    expect(match.confident,true);
  });
  test('M950-P10 unsupported verified suffix mapping never produces fake account',(){
    final match=choose(source:'1234',verified:{
      'unrelated':'0000','malformed':'٠١٢',
    });
    expect(match.accountId,null);
    expect(match.confident,false);
  });
  test('M950-P11 selected account view rejects empty selection without widening to all',(){
    final row=entry('id',500,account:'a');
    expect(()=>WaffraAccountContextPolicy.visible(
      row,WaffraAccountView.selected,selectedAccountId:''),
      throwsArgumentError);
    expect(WaffraAccountContextPolicy.visible(
      row,WaffraAccountView.all),true);
  });
  test('M950-P12 unassigned debit and credit remain visible in All but neither bank',(){
    final rows=[entry('credit',750,income:true),entry('debit',250),
      entry('bank-credit',300,account:'bank',income:true)];
    expect(rows.where((r)=>WaffraAccountContextPolicy.visible(
      r,WaffraAccountView.unassigned)).map((r)=>r.id).toList(),
      ['credit','debit']);
    expect(rows.where((r)=>WaffraAccountContextPolicy.visible(
      r,WaffraAccountView.selected,selectedAccountId:'bank'))
      .map((r)=>r.id).toList(),['bank-credit']);
  });
  test('M950-P13 matched account cash delta includes credit and expense but not other',(){
    final rows=[entry('plus',101,account:'bank',income:true),
      entry('minus',52,account:'bank'),entry('other',999,account:'wallet')];
    expect(rows.fold<int>(0,(n,r)=>n+
      WaffraAccountContextPolicy.balanceDelta(r,'bank')),49);
    expect(rows.fold<int>(0,(n,r)=>n+
      WaffraAccountContextPolicy.balanceDelta(r,'unknown')),0);
  });
  test('M950-P14 budget global spending includes unassigned and other bank not incomes',(){
    final rows=[entry('a',200,account:'bank',budget:'food'),
      entry('b',300,account:'wallet',budget:'food'),
      entry('c',100,budget:'food'),
      entry('income',1000000,account:'bank',budget:'food',income:true),
      entry('unrelated',9999,account:'bank',budget:'rent')];
    final usage=WaffraAccountContextPolicy.budget(
      entries:rows,budgetId:'food',limitMinor:1000,
      selectedAccountId:'bank');
    expect(usage.globalSpentMinor,600);
    expect(usage.selectedAccountSpentMinor,200);
    expect(usage.reached(60),true);
    expect(usage.reached(61),false);
  });
  test('M950-P15 changing account header cannot alter global budget warning threshold',(){
    final rows=[entry('a',499,account:'a',budget:'food'),
      entry('b',1,account:'b',budget:'food')];
    final a=WaffraAccountContextPolicy.budget(
      entries:rows,budgetId:'food',limitMinor:1000,selectedAccountId:'a');
    final b=WaffraAccountContextPolicy.budget(
      entries:rows,budgetId:'food',limitMinor:1000,selectedAccountId:'b');
    expect(a.selectedAccountSpentMinor,499);
    expect(b.selectedAccountSpentMinor,1);
    expect(a.globalSpentMinor,b.globalSpentMinor);
    expect(a.reached(50),true);
    expect(b.reached(50),true);
  });
  test('M950-P16 rejected invalid budget row cannot be dismissed by selected other bank',(){
    final rows=[entry('wrong',0,account:'b',budget:'food')];
    expect(()=>WaffraAccountContextPolicy.budget(
      entries:rows,budgetId:'food',limitMinor:1000,selectedAccountId:'a'),
      throwsStateError);
  });
  test('M950-P17 budget ignores nonmatching invalid row and does not consume unrelated category',(){
    final rows=[entry('wrong',0,budget:'rent'),
      entry('ok',275,account:'bank',budget:'food')];
    final food=WaffraAccountContextPolicy.budget(
      entries:rows,budgetId:'food',limitMinor:500,selectedAccountId:'bank');
    expect(food.globalSpentMinor,275);
    expect(food.selectedAccountSpentMinor,275);
  });
  test('M950-P18 fully released source ends at exact zero while unrelated bank savings persist',(){
    final events=[movement('fund-bank-1','bank',2000),
      movement('fund-wallet','wallet',1500),
      movement('release-bank-1','bank',1200,release:true),
      movement('release-bank-2','bank',800,release:true)];
    expect(WaffraAccountContextPolicy.goalContribution(events,'bank'),0);
    expect(WaffraAccountContextPolicy.goalContribution(events,'wallet'),1500);
    expect(WaffraAccountContextPolicy.goalContribution(events,'cash'),0);
  });
  test('M950-P19 duplicated goal wallet movement across accounts rejects whole projection',(){
    final events=[movement('same','bank',1200),
      movement('same','wallet',1200,release:true)];
    expect(()=>WaffraAccountContextPolicy.goalContribution(events,'bank'),
      throwsStateError);
  });
  test('M950-P20 two successive one-time due account overrides leave original future bank intact',(){
    final first=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:'bank',chosenAccountId:'wallet',
      change:WaffraRecurringAccountChange.thisPaymentOnly);
    final second=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:first.nextDefaultAccountId,
      chosenAccountId:'cash',
      change:WaffraRecurringAccountChange.thisPaymentOnly);
    expect(first.paymentAccountId,'wallet');
    expect(second.paymentAccountId,'cash');
    expect(first.nextDefaultAccountId,'bank');
    expect(second.nextDefaultAccountId,'bank');
  });
  test('M950-P21 first recurring default creation then explicit future switch does not reuse prior owner',(){
    final first=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:null,chosenAccountId:'wallet',
      change:WaffraRecurringAccountChange.futurePayments);
    final next=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:first.nextDefaultAccountId,
      chosenAccountId:'bank',change:WaffraRecurringAccountChange.futurePayments);
    expect(first.paymentAccountId,'wallet');
    expect(first.nextDefaultAccountId,'wallet');
    expect(next.paymentAccountId,'bank');
    expect(next.nextDefaultAccountId,'bank');
  });
  test('M950-P22 one-time recurring selection cleared retains future default',(){
    final actual=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:'bank',chosenAccountId:null,
      change:WaffraRecurringAccountChange.thisPaymentOnly);
    expect(actual.paymentAccountId,null);
    expect(actual.nextDefaultAccountId,'bank');
  });
  test('M950-P23 clearing future recurring account never silently uses previous bank',(){
    final actual=WaffraAccountContextPolicy.recurringAccount(
      savedDefaultAccountId:'bank',chosenAccountId:null,
      change:WaffraRecurringAccountChange.futurePayments);
    expect(actual.paymentAccountId,null);
    expect(actual.nextDefaultAccountId,null);
  });
  test('M950-P24 overdue unpaid recurring schedule remains actionable on prior due day',(){
    final actual=WaffraRecurringPolicy.nextActionableDue(
      today:DateTime(2026,11,30),startAt:DateTime(2024,4,15),day:5,
      currentMonthPaid:false);
    expect(actual,DateTime(2026,11,5));
  });
  test('M950-P25 paying overdue recurring after postponement shows next month instead',(){
    final actual=WaffraRecurringPolicy.nextActionableDue(
      today:DateTime(2026,11,30),startAt:DateTime(2024,4,15),day:5,
      currentMonthPaid:true,postponedUntil:DateTime(2026,12,10));
    expect(actual,DateTime(2026,12,5));
  });
  test('M950-P26 schedule starting after current due rolls into next month',(){
    final actual=WaffraRecurringPolicy.nextActionableDue(
      today:DateTime(2026,11,17),startAt:DateTime(2026,11,20),
      day:5,currentMonthPaid:false);
    expect(actual,DateTime(2026,12,5));
  });
  test('M950-P27 postponed due keeps original monthly posting identity',(){
    final due=WaffraRecurringPolicy.dueDate(2026,11,5);
    final moved=WaffraRecurringPolicy.nextActionableDue(
      today:DateTime(2026,11,6),startAt:DateTime(2026,1,1),day:5,
      currentMonthPaid:false,postponedUntil:DateTime(2026,12,10));
    expect(moved,DateTime(2026,12,10));
    expect(WaffraRecurringPolicy.entryId('rent',due),
      'rec_rent_2026_11');
    expect(WaffraRecurringPolicy.entryId('rent',due),
      isNot(WaffraRecurringPolicy.entryId('rent',moved)));
  });
  test('M950-P28 future schedule starts after clamped February due and waits March',(){
    final next=WaffraRecurringPolicy.nextDueDate(
      today:DateTime(2027,2,28),startAt:DateTime(2027,2,28),
      day:30);
    expect(next,DateTime(2027,2,28));
    final later=WaffraRecurringPolicy.nextDueDate(
      today:DateTime(2027,3,1),startAt:DateTime(2027,2,28),
      day:30);
    expect(later,DateTime(2027,3,30));
  });
}

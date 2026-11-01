import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_financial_planning_engine.dart';

void main() {
 group('M342 goal wallets — conservation and error handling', () {
  test('funding reserves money without creating an expense', () {
   final result=GoalWalletProjector.replay(
     300000,{'car':0},[const GoalMove('fund-1',GoalMoveKind.fund,100000,to:'car')]);
   expect(result.spendableMinor,200000);
   expect(result.goalsMinor['car'],100000);
   expect(result.totalMinor,300000);
  });
  test('withdraw and cross-goal move preserve total', () {
   final result=GoalWalletProjector.replay(200000,{'car':100000,'travel':0},[
    const GoalMove('move-1',GoalMoveKind.transfer,30000,from:'car',to:'travel'),
    const GoalMove('withdraw-1',GoalMoveKind.withdraw,20000,from:'car'),
   ]);
   expect(result.goalsMinor,{'car':50000,'travel':30000});
   expect(result.spendableMinor,220000);
   expect(result.totalMinor,300000);
  });
  test('duplicate, overfund and invalid goal access fail closed', () {
   expect(()=>GoalWalletProjector.replay(100,{'car':0},[
    const GoalMove('a',GoalMoveKind.fund,60,to:'car'),
    const GoalMove('a',GoalMoveKind.fund,20,to:'car'),
   ]),throwsStateError);
   expect(()=>GoalWalletProjector.replay(100,{'car':0},[
    const GoalMove('overfund',GoalMoveKind.fund,101,to:'car'),
   ]),throwsStateError);
   expect(()=>GoalWalletProjector.replay(100,{'car':0},[
    const GoalMove('unknown',GoalMoveKind.fund,10,to:'not-a-goal'),
   ]),throwsStateError);
  });
 });

 group('M342 named budgets — stable identifiers and no double counting', () {
  final start=DateTime(2026,11,1),end=DateTime(2026,12,1);
  late List<NamedBudget> budgets;
  setUp(() {
    budgets=[
     NamedBudget('fuel','وقود السيارة','car-fuel',20000,start,end),
     NamedBudget('trip','رحلة','car-fuel',10000,start,end),
    ];
  });
  test('75 SAR spent on 200 SAR fuel budget leaves 125 SAR', () {
   final projection=NamedBudgetProjector.review(budgets,[
     PostedExpense('gas-1','car-fuel',7500,DateTime(2026,11,3)),
   ],[const BudgetAllocation('gas-1','fuel',7500)]);
   expect(projection.positions['fuel']!.remainingMinor,12500);
   expect(projection.unassigned,isEmpty);
   expect(projection.positions['fuel']!.alertPercent,0);
  });
  test('split allocation and later edit change totals exactly once', () {
   final original=PostedExpense('gas-1','car-fuel',7500,DateTime(2026,11,3));
   final links=[
    const BudgetAllocation('gas-1','fuel',5000),
    const BudgetAllocation('gas-1','trip',2000),
   ];
   final before=NamedBudgetProjector.review(budgets,[original],links);
   expect(before.positions['fuel']!.usedMinor,5000);
   expect(before.positions['trip']!.usedMinor,2000);
   expect(before.unassigned['gas-1'],500);
   final edited=NamedBudgetProjector.review(budgets,[
     PostedExpense('gas-1','car-fuel',9000,DateTime(2026,11,3)),
   ],links);
   expect(edited.unassigned['gas-1'],2000);
   expect(edited.positions['fuel']!.usedMinor,5000);
   final deleted=NamedBudgetProjector.review(budgets,[],[]);
   expect(deleted.positions['fuel']!.usedMinor,0);
  });
  test('budget rename does not break immutable id links', () {
   final renamed=[NamedBudget('fuel','بنزين', 'car-fuel',20000,start,end)];
   final result=NamedBudgetProjector.review(renamed,[
    PostedExpense('p','car-fuel',18000,DateTime(2026,11,12)),
   ],[const BudgetAllocation('p','fuel',18000)]);
   expect(result.positions['fuel']!.alertPercent,80);
   expect(result.positions['fuel']!.remainingMinor,2000);
  });
  test('overallocation and cross-category link fail', () {
   final expenses=[PostedExpense('p','car-fuel',7500,DateTime(2026,11,3))];
   expect(()=>NamedBudgetProjector.review(budgets,expenses,[
    const BudgetAllocation('p','fuel',7500),
    const BudgetAllocation('p','trip',1),
   ]),throwsStateError);
   expect(()=>NamedBudgetProjector.review(budgets,[
    PostedExpense('p','groceries',7500,DateTime(2026,11,3)),
   ],[const BudgetAllocation('p','fuel',7500)]),throwsStateError);
   expect(()=>NamedBudgetProjector.review(budgets,[
    PostedExpense('p','car-fuel',7500,DateTime(2026,12,1)),
   ],[const BudgetAllocation('p','fuel',7500)]),throwsStateError);
  });
  test('unconfirmed OCR/preauthorization cannot count as budget spend', () {
   final draft=PostedExpense('pending','car-fuel',857,
     DateTime(2026,11,3),confirmed:false);
   expect(NamedBudgetProjector.review(budgets,[draft],[]).unassigned,isEmpty);
   expect(()=>NamedBudgetProjector.review(budgets,[draft],[
    const BudgetAllocation('pending','fuel',857),
   ]),throwsStateError);
  });
 });

 group('M342 recurring reconciliation — suggestions, never writes', () {
  test('month-end clamps, weekly advances, leap day yearly preserves date', () {
   expect(RecurringPaymentReview.nextDue(
    RecurringPlan('m',DateTime(2026,1,31),RecurringFrequency.monthly,
      5000,'housing'),DateTime(2026,2,1)),DateTime(2026,2,28));
   expect(RecurringPaymentReview.nextDue(
    RecurringPlan('w',DateTime(2026,11,1),RecurringFrequency.weekly,
      5000,'housing'),DateTime(2026,11,5)),DateTime(2026,11,8));
   expect(RecurringPaymentReview.nextDue(
    RecurringPlan('y',DateTime(2024,2,29),RecurringFrequency.yearly,
      5000,'housing'),DateTime(2027,2,1)),DateTime(2027,2,28));
  });
  test('matched bank payment proposed once, without forging paid state', () {
   final plan=RecurringPlan('rent',DateTime(2026,11,1),
    RecurringFrequency.monthly,200000,'housing',
    merchantKey:'landlord');
   final payment=BankPaymentEvidence('bank-confirmed',DateTime(2026,11,2),
    200000,'housing',merchantKey:'landlord',confirmed:true);
   expect(RecurringPaymentReview.matches(plan,payment,
    expectedDue:DateTime(2026,11,1)),isTrue);
   expect(RecurringPaymentReview.matches(plan,
    BankPaymentEvidence('unconfirmed',DateTime(2026,11,2),
     200000,'housing',merchantKey:'landlord',confirmed:false),
    expectedDue:DateTime(2026,11,1)),isFalse);
   expect(RecurringPaymentReview.matches(plan,
    BankPaymentEvidence('different',DateTime(2026,11,2),
     200000,'housing',merchantKey:'other',confirmed:true),
    expectedDue:DateTime(2026,11,1)),isFalse);
  });
 });

 group('M342 budget amendments — creation after transactions and delete', () {
  final start=DateTime(2026,11,1),end=DateTime(2026,12,1);
  test('old expense becomes a review suggestion after budget creation', () {
   final expenses=[
    PostedExpense('prior-purchase','fuel',7500,DateTime(2026,11,4)),
   ];
   final created=[
    NamedBudget('my-fuel','ميزانية البنزين','fuel',20000,start,end),
   ];
   final proposed=BudgetChangeReview.suggestUnlinked(created,expenses,[]);
   expect(proposed['prior-purchase'],['my-fuel']);
   expect(NamedBudgetProjector.review(created,expenses,[])
       .unassigned['prior-purchase'],7500);
  });
  test('budget deletion detaches its links and preserves actual expense', () {
   final budget=NamedBudget('fuel','وقود','car',20000,start,end);
   final expense=PostedExpense('p','car',7500,DateTime(2026,11,3));
   final removal=BudgetChangeReview.deleteBudget('fuel',[budget],
    [expense],[const BudgetAllocation('p','fuel',7500)]);
   expect(removal.remainingBudgets,isEmpty);
   expect(removal.remainingLinks,isEmpty);
   expect(removal.recalculated.unassigned['p'],7500);
  });
  test('duplicate category budgets must not auto-assign by guesswork', () {
   final budgets=[
    NamedBudget('fuel','الوقود','car',20000,start,end),
    NamedBudget('travel','السفر','car',10000,start,end),
   ];
   final matches=BudgetChangeReview.suggestUnlinked(budgets,[
    PostedExpense('p','car',7500,DateTime(2026,11,3)),
   ],[]);
   expect(matches['p'],['fuel','travel']);
   // Multiple valid options are presented for review, never auto-saved.
  });
 });


 group('M342 cautious multi-obligation bank matching', () {
  test('one confirmed merchant payment is uniquely suggested', () {
   final plan=RecurringPlan('bill',DateTime(2026,11,1),
     RecurringFrequency.monthly,4000,'utilities',merchantKey:'power');
   final result=RecurringBatchMatcher.review(plans:[plan],
    dues:[RecurringDueObligation('bill',DateTime(2026,11,1))],
    payments:[
     BankPaymentEvidence('bank-1',DateTime(2026,11,2),
      4000,'utilities',merchantKey:'power',confirmed:true),
    ]);
   expect(result.uniqueSuggestions,{'bill@2026-11-01':'bank-1'});
   expect(result.ambiguousOccurrences,isEmpty);
   expect(result.unmatchedPaymentIds,isEmpty);
  });
  test('one payment matching two standing orders must abstain', () {
   final plans=[
    RecurringPlan('a',DateTime(2026,11,1),RecurringFrequency.monthly,
      1000,'digital',merchantKey:'streaming'),
    RecurringPlan('b',DateTime(2026,11,1),RecurringFrequency.monthly,
      1000,'digital',merchantKey:'streaming'),
   ];
   final result=RecurringBatchMatcher.review(plans:plans,
    dues:[
     RecurringDueObligation('a',DateTime(2026,11,1)),
     RecurringDueObligation('b',DateTime(2026,11,1))],
    payments:[BankPaymentEvidence('one-payment',
     DateTime(2026,11,1),1000,'digital',
     merchantKey:'streaming',confirmed:true)]);
   expect(result.uniqueSuggestions,isEmpty);
   expect(result.ambiguousOccurrences,
      {'a@2026-11-01','b@2026-11-01'});
   expect(result.unmatchedPaymentIds,{'one-payment'});
  });
  test('two matching bank payments for one due must abstain', () {
   final plan=RecurringPlan('fuel',DateTime(2026,11,1),
     RecurringFrequency.monthly,5000,'fuel',merchantKey:'station');
   final result=RecurringBatchMatcher.review(plans:[plan],
    dues:[RecurringDueObligation('fuel',DateTime(2026,11,1))],
    payments:[
     BankPaymentEvidence('a',DateTime(2026,11,1),
       5000,'fuel',merchantKey:'station',confirmed:true),
     BankPaymentEvidence('b',DateTime(2026,11,2),
       5000,'fuel',merchantKey:'station',confirmed:true)]);
   expect(result.uniqueSuggestions,isEmpty);
   expect(result.ambiguousOccurrences,{'fuel@2026-11-01'});
  });
  test('paid occurrence is not matched again', () {
   final plan=RecurringPlan('rent',DateTime(2026,11,1),
     RecurringFrequency.monthly,200000,'housing',merchantKey:'landlord');
   final result=RecurringBatchMatcher.review(plans:[plan],
    dues:[RecurringDueObligation('rent',DateTime(2026,11,1),
      alreadyPaid:true)],
    payments:[BankPaymentEvidence('bank',DateTime(2026,11,1),
      200000,'housing',merchantKey:'landlord',confirmed:true)]);
   expect(result.uniqueSuggestions,isEmpty);
   expect(result.unmatchedPaymentIds,{'bank'});
  });
  test('duplicate bank ids cannot create two matches', () {
   final plan=RecurringPlan('x',DateTime(2026,11,1),
      RecurringFrequency.monthly,5000,'bill',merchantKey:'provider');
   expect(()=>RecurringBatchMatcher.review(plans:[plan],dues:[
     RecurringDueObligation('x',DateTime(2026,11,1))],payments:[
     BankPaymentEvidence('dup',DateTime(2026,11,1),5000,'bill',
       merchantKey:'provider',confirmed:true),
     BankPaymentEvidence('dup',DateTime(2026,11,1),5000,'bill',
       merchantKey:'provider',confirmed:true),
   ]),throwsStateError);
  });
 });


 group('M342 goal wallet health audit: do not mutate legacy snapshots', () {
  test('goal allocations are independent of consumer expenses', () {
   final result=GoalWalletHealthAudit.inspect(300000,[
    const GoalAmountEvidence('car',500000,100000),
   ]);
   expect(result.availableMinor,200000);
   expect(result.reservedMinor,100000);
   expect(result.reconciled,isTrue);
   expect(result.netLedgerMinor,300000);
  });
  test('more reserved than ledger cash is a warning, never clamped', () {
   final result=GoalWalletHealthAudit.inspect(50000,[
    const GoalAmountEvidence('car',200000,100000),
   ]);
   expect(result.availableMinor,-50000);
   expect(result.issues,contains('goals_exceed_spendable_ledger'));
  });
  test('duplicate goal IDs and malformed snapshots are surfaced', () {
   final result=GoalWalletHealthAudit.inspect(100000,[
    const GoalAmountEvidence('a',5000,1000),
    const GoalAmountEvidence('a',5000,1000),
    const GoalAmountEvidence('b',-10,-20),
   ]);
   expect(result.issues,contains('duplicate_or_missing_goal_id'));
   expect(result.issues,contains('invalid_goal_amount'));
  });
 });

}

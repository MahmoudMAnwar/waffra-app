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
}

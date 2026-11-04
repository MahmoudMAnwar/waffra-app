import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_advanced_planning_policies.dart';

void main() {
 group('M347 budget cycles and capped rollover',(){
  test('weekly starts Monday and crosses calendar year',(){
   final cycle=WaffraBudgetPeriods.covering(
     DateTime(2027,1,1),WaffraBudgetInterval.weekly);
   expect(cycle.start,DateTime(2026,12,28));
   expect(cycle.endExclusive,DateTime(2027,1,4));
   expect(cycle.days,7);
  });
  test('February, leap-year and annual periods are calendar aware',(){
   final leap=WaffraBudgetPeriods.covering(
     DateTime(2028,2,29),WaffraBudgetInterval.monthly);
   expect(leap.start,DateTime(2028,2,1));
   expect(leap.endExclusive,DateTime(2028,3,1));
   expect(leap.days,29);
   final year=WaffraBudgetPeriods.covering(
      DateTime(2028,6,1),WaffraBudgetInterval.annual);
   expect(year.days,366);
  });
  test('custom budgets reject invalid bounds',(){
   expect(()=>WaffraBudgetPeriods.covering(DateTime(2026,11,2),
      WaffraBudgetInterval.custom,customStart:DateTime(2026,11,3),
      customEndExclusive:DateTime(2026,12,1)),throwsStateError);
   expect(WaffraBudgetPeriods.covering(DateTime(2026,11,10),
      WaffraBudgetInterval.custom,customStart:DateTime(2026,11,3),
      customEndExclusive:DateTime(2026,12,1)).contains(DateTime(2026,11,30)),
      isTrue);
  });
  test('roll unused 200 SAR capped at 100, no negative credit',(){
   const rollover=WaffraRolloverPlan(baseLimitMinor:30000,
     previousLimitMinor:20000,previousSpentMinor:0,
     enabled:true,maximumCarryMinor:10000);
   expect(rollover.carryMinor,10000);
   expect(rollover.effectiveLimitMinor,40000);
   const overspent=WaffraRolloverPlan(baseLimitMinor:30000,
     previousLimitMinor:20000,previousSpentMinor:25000,
     enabled:true,maximumCarryMinor:10000);
   expect(overspent.carryMinor,0);
   expect(overspent.effectiveLimitMinor,30000);
   const disabled=WaffraRolloverPlan(baseLimitMinor:30000,
     previousLimitMinor:20000,previousSpentMinor:0,
     enabled:false,maximumCarryMinor:10000);
   expect(disabled.carryMinor,0);
  });
 });
 group('M347 recurring variable-bill review',(){
  test('variable invoice is draft until explicitly approved',(){
   const draft=WaffraRecurringAmountReview(occurrenceKey:'bill-2026-11',
    proposedMinor:9000,currency:'SAR',userApproved:false);
   expect(draft.reviewedAmountMinor,isNull);
   const confirmed=WaffraRecurringAmountReview(occurrenceKey:'bill-2026-11',
    proposedMinor:9000,currency:'SAR',userApproved:true,
    approvedMinor:11300);
   expect(confirmed.reviewedAmountMinor,11300);
  });
  test('foreign currency and invalid approvals are blocked',(){
   expect(()=>const WaffraRecurringAmountReview(occurrenceKey:'bill',
    proposedMinor:2000,currency:'JOD',userApproved:true,
    approvedMinor:2000).reviewedAmountMinor,throwsStateError);
   expect(()=>const WaffraRecurringAmountReview(occurrenceKey:'bill',
    proposedMinor:2000,currency:'SAR',userApproved:true)
    .reviewedAmountMinor,throwsStateError);
  });
 });
 group('M347 merchant corrections require unique confirmed evidence',(){
  final valid={'food','groceries','health'};
  test('two confirmed corrections enable exact merchant suggestion',(){
   final learned=WaffraMerchantPersonalLearning.learn([
    const WaffraMerchantCorrection(transactionId:'a',
     merchantKey:'Keeta',categoryId:'food',income:false,userConfirmed:true),
    const WaffraMerchantCorrection(transactionId:'b',
     merchantKey:'Keeta',categoryId:'food',income:false,userConfirmed:true),
    const WaffraMerchantCorrection(transactionId:'c',
     merchantKey:'Keemart',categoryId:'groceries',income:false,userConfirmed:true),
   ],validCategoryIds:valid);
   expect(WaffraMerchantPersonalLearning.suggest(learned,
      'KEETA',income:false),'food');
   expect(WaffraMerchantPersonalLearning.suggest(learned,
      'Keemart',income:false),isNull);
   expect(WaffraMerchantPersonalLearning.suggest(learned,
      'Keeta',income:true),isNull);
  });
  test('conflicts abstain; OTP/account numbers never become merchants',(){
   final learned=WaffraMerchantPersonalLearning.learn([
    const WaffraMerchantCorrection(transactionId:'a',merchantKey:'Cafe',
     categoryId:'food',income:false,userConfirmed:true),
    const WaffraMerchantCorrection(transactionId:'b',merchantKey:'Cafe',
     categoryId:'health',income:false,userConfirmed:true),
    const WaffraMerchantCorrection(transactionId:'c',merchantKey:'Cafe',
     categoryId:'food',income:false,userConfirmed:true),
   ],validCategoryIds:valid);
   expect(WaffraMerchantPersonalLearning.suggest(learned,
    'Cafe',income:false),isNull);
   expect(()=>WaffraMerchantPersonalLearning.learn([
    const WaffraMerchantCorrection(transactionId:'safe',merchantKey:'Account 1234',
     categoryId:'food',income:false,userConfirmed:true)
   ],validCategoryIds:valid),throwsStateError);
  });
  test('same transaction id cannot train merchant twice',(){
   expect(()=>WaffraMerchantPersonalLearning.learn([
    const WaffraMerchantCorrection(transactionId:'id',
     merchantKey:'Keeta',categoryId:'food',income:false,userConfirmed:true),
    const WaffraMerchantCorrection(transactionId:'id',
     merchantKey:'Keeta',categoryId:'food',income:false,userConfirmed:true),
   ],validCategoryIds:valid),throwsStateError);
  });
 });
}

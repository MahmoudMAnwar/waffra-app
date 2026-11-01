/// M347: policy-only extensions for planning. No ledger, widget or SQL writes.
/// SAR values use integer halalas. A source currency must be checked upstream.
enum WaffraBudgetInterval { weekly, monthly, annual, custom }

class WaffraCivilWindow {
 const WaffraCivilWindow(this.start,this.endExclusive);
 final DateTime start,endExclusive;
 bool contains(DateTime date)=>!date.isBefore(start)&&date.isBefore(endExclusive);
 int get days=>DateTime.utc(endExclusive.year,endExclusive.month,
    endExclusive.day).difference(DateTime.utc(start.year,start.month,
    start.day)).inDays;
}

/// An explicit, non-overlapping period. Weekly starts on Monday; monthly and
/// annual use calendar boundaries, not 30- or 365-day approximations.
abstract final class WaffraBudgetPeriods {
 static WaffraCivilWindow covering(DateTime date,WaffraBudgetInterval interval,
      {DateTime? customStart,DateTime? customEndExclusive}) {
  final day=DateTime(date.year,date.month,date.day);
  switch(interval) {
   case WaffraBudgetInterval.weekly:
    final start=day.subtract(Duration(days:day.weekday-DateTime.monday));
    return WaffraCivilWindow(start,DateTime(start.year,start.month,start.day+7));
   case WaffraBudgetInterval.monthly:
    return WaffraCivilWindow(DateTime(day.year,day.month),
       DateTime(day.year,day.month+1));
   case WaffraBudgetInterval.annual:
    return WaffraCivilWindow(DateTime(day.year),
       DateTime(day.year+1));
   case WaffraBudgetInterval.custom:
    if(customStart==null||customEndExclusive==null) {
      throw StateError('Custom budget needs verified start/end');
    }
    final start=DateTime(customStart.year,customStart.month,customStart.day);
    final end=DateTime(customEndExclusive.year,
      customEndExclusive.month,customEndExclusive.day);
    if(!start.isBefore(end)||day.isBefore(start)||!day.isBefore(end)) {
      throw StateError('Date outside custom budget period');
    }
    return WaffraCivilWindow(start,end);
  }
 }
}

class WaffraRolloverPlan {
 const WaffraRolloverPlan({
  required this.baseLimitMinor,required this.previousLimitMinor,
  required this.previousSpentMinor,
  this.previousCarryMinor=0,this.enabled=false,
  this.maximumCarryMinor=0,
 });
 final int baseLimitMinor,previousLimitMinor,previousSpentMinor;
 final int previousCarryMinor,maximumCarryMinor;
 final bool enabled;
 /// Only unspent funds roll forward. Overspending never produces credit.
 /// Current-period calculations never mutate last month's ledger.
 int get carryMinor {
   if(baseLimitMinor<=0||previousLimitMinor<=0||
       previousSpentMinor<0||previousCarryMinor<0||maximumCarryMinor<0) {
     throw StateError('Invalid rollover provenance');
   }
   if(!enabled)return 0;
   final left=previousLimitMinor+previousCarryMinor-previousSpentMinor;
   if(left<=0)return 0;
   return left<maximumCarryMinor?left:maximumCarryMinor;
 }
 int get effectiveLimitMinor=>baseLimitMinor+carryMinor;
}

class WaffraRecurringAmountReview {
 const WaffraRecurringAmountReview({
  required this.occurrenceKey,required this.proposedMinor,
  required this.currency,required this.userApproved,
  this.approvedMinor,
 });
 final String occurrenceKey,currency;
 final int proposedMinor;
 final int? approvedMinor;
 final bool userApproved;
 /// Without explicit user review, a variable bill cannot become a ledger
 /// charge. This result is a draft only; never an automatic payment.
 int? get reviewedAmountMinor {
  if(occurrenceKey.trim().isEmpty||currency!='SAR'||proposedMinor<=0){
    throw StateError('Invalid recurring proposal');
  }
  if(!userApproved)return null;
  if(approvedMinor==null||approvedMinor!<=0) {
    throw StateError('User approval missing valid amount');
  }
  return approvedMinor;
 }
}

class WaffraMerchantCorrection {
 const WaffraMerchantCorrection({
  required this.transactionId,required this.merchantKey,
  required this.categoryId,required this.income,
  required this.userConfirmed,
 });
 final String transactionId,merchantKey,categoryId;
 final bool income,userConfirmed;
}

class WaffraMerchantPreference {
 const WaffraMerchantPreference(this.categoryId,this.confirmations);
 final String categoryId;
 final int confirmations;
}

/// No raw bank SMS, card IDs or fuzzy aliases are learned. Exact merchant
/// names can become a suggestion ONLY after two independent confirmations.
/// Conflicting preferences always abstain, never reclassify old entries.
abstract final class WaffraMerchantPersonalLearning {
 static String normalize(String raw) => raw.toLowerCase().trim()
  .replaceAll(RegExp(r'[\u200e\u200f\u061c]'),'')
  .replaceAll(RegExp(r'[\u064b-\u065f]'),'')
  .replaceAll(RegExp(r'[أإآ]'),'ا')
  .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064a ]'),' ')
  .replaceAll(RegExp(r'\s+'),' ').trim();

 static Map<(String,bool),WaffraMerchantPreference> learn(
   Iterable<WaffraMerchantCorrection> corrections,{
   required Set<String> validCategoryIds,
 }) {
  final grouped=<(String,bool),Map<String,Set<String>>>{};
  final seen=<String>{};
  for(final row in corrections) {
   if(!row.userConfirmed)continue;
   final key=normalize(row.merchantKey);
   if(row.transactionId.trim().isEmpty||
      !seen.add(row.transactionId)||key.length<2||
      key.length>90||RegExp(r'\d{4,}|iban|account|acct|card|حساب|بطاقة',
        caseSensitive:false).hasMatch(key)||
      !validCategoryIds.contains(row.categoryId)) {
     throw StateError('Invalid merchant training evidence');
   }
   (grouped[(key,row.income)]??=<String,Set<String>>{})
     .putIfAbsent(row.categoryId,()=> <String>{})
     .add(row.transactionId);
  }
  return Map.unmodifiable({
   for(final row in grouped.entries)
    if(row.value.length==1&&row.value.values.single.length>=2)
      row.key:WaffraMerchantPreference(
       row.value.keys.single,row.value.values.single.length),
  });
 }

 static String? suggest(
   Map<(String,bool),WaffraMerchantPreference> preferences,
   String merchant,{required bool income}
 )=>preferences[(normalize(merchant),income)]?.categoryId;
}

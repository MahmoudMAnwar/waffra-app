/// M345: deterministic read-only finance planning. Currency is SAR halalas.
/// Never posts savings, creates a payment, or rewrites legacy aggregates.
class WaffraGoalPlan {
  const WaffraGoalPlan({required this.targetMinor,required this.savedMinor,
      required this.today,required this.dueDate});
  final int targetMinor,savedMinor;
  final DateTime today,dueDate;

  int get remainingMinor => targetMinor > savedMinor
      ? targetMinor-savedMinor : 0;

  bool get overdue => remainingMinor>0 &&
      DateTime(dueDate.year,dueDate.month,dueDate.day).isBefore(
        DateTime(today.year,today.month,today.day));

  /// Counts payable calendar months including the current month, never
  /// pretending a due date in the past is eligible.
  int get monthsAvailable {
    if(overdue)return 0;
    final todayDate=DateTime(today.year,today.month,today.day);
    if(dueDate.isBefore(todayDate))return 0;
    return (dueDate.year-today.year)*12 + dueDate.month-today.month+1;
  }

  /// Ceiling in halalas prevents a rounded-down recommendation from falling
  /// short of the target on the last installment.
  int? get monthlyRequiredMinor {
    if(targetMinor<=0||savedMinor<0)throw StateError('Invalid goal balances');
    if(remainingMinor==0)return 0;
    final months=monthsAvailable;
    if(months<=0)return null;
    return (remainingMinor+months-1)~/months;
  }

  DateTime? projectedCompletion({required int monthlyPledgeMinor}) {
    if(targetMinor<=0||savedMinor<0||monthlyPledgeMinor<=0) {
      throw StateError('Invalid goal forecast input');
    }
    if(remainingMinor==0)return DateTime(today.year,today.month,today.day);
    final months=(remainingMinor+monthlyPledgeMinor-1)~/monthlyPledgeMinor;
    if(months>1200)return null; // avoid misleading centuries-ahead forecasts
    return DateTime(today.year,today.month+months-1,
        today.day.clamp(1,DateTime(today.year,today.month+months,0).day).toInt());
  }
}

class WaffraBudgetPace {
 const WaffraBudgetPace({
  required this.spentMinor,required this.limitMinor,
  required this.dayOfPeriod,required this.daysInPeriod});
 final int spentMinor,limitMinor,dayOfPeriod,daysInPeriod;

 int get forecastMinor {
   if(spentMinor<0||limitMinor<=0||dayOfPeriod<=0||
      daysInPeriod<=0||dayOfPeriod>daysInPeriod) {
     throw StateError('Invalid budget pace inputs');
   }
   return (spentMinor*daysInPeriod+dayOfPeriod-1)~/dayOfPeriod;
 }
 int get warningStage {
   if(limitMinor<=0||spentMinor<0)throw StateError('Invalid budget');
   if(spentMinor>=limitMinor)return 100;
   if(spentMinor*100>=limitMinor*80)return 80;
   if(spentMinor*100>=limitMinor*50)return 50;
   return 0;
 }
 bool get projectedOverBudget =>forecastMinor>limitMinor;
}

/// Strict checked migration from existing finance doubles to SAR minor units.
/// Do not silently round 3-decimal foreign amounts into this SAR-only policy.
int waffraSarMinorChecked(num value) {
 final number=value.toDouble();
 if(!number.isFinite||number<0||number>100000000000) {
   throw StateError('Invalid SAR amount');
 }
 final minor=(number*100).round();
 if((minor/100-number).abs()>0.000001) {
   throw StateError('Unapproved fractional SAR amount');
 }
 return minor;
}

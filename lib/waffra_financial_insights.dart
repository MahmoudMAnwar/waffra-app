import 'dart:math' as math;

/// Deterministic calculations only. Never connects to a bank account.
class WaffraFinancialInsights {
 const WaffraFinancialInsights._();

 static double projectedEndBalance({
  required double currentBalance,
  required double variableExpensesSoFar,
  required int daysElapsed,
  required int daysInMonth,
  double pendingRecurringIncome=0,
  double pendingRecurringExpense=0,
 }) {
  if(daysElapsed<=0||daysInMonth<=0||daysElapsed>daysInMonth) return currentBalance;
  final remaining=math.max(0,daysInMonth-daysElapsed);
  final dailyAverage=math.max(0,variableExpensesSoFar)/daysElapsed;
  return currentBalance-dailyAverage*remaining+pendingRecurringIncome-pendingRecurringExpense;
 }

 static double dailyAllowance({
  required double monthlyBudget,
  required double spent,
  required int daysRemaining,
 }) {
  if(monthlyBudget<=0||daysRemaining<=0)return 0;
  return math.max(0,monthlyBudget-spent)/daysRemaining;
 }

 static double? comparisonPercent(double current,double previous){
  if(previous<=0)return null;
  return (current-previous)/previous*100;
 }

 /// A selected percentage must apply to every budget warning surface.
 static bool reachedBudgetThreshold({
  required double spent,required double budget,required int alertPercent,
 }){
  if(budget<=0||alertPercent<1||alertPercent>100)return false;
  return spent>=budget*alertPercent/100;
 }

 /// A future-start or already-paid obligation must not lower this month's
 /// read-only forecast. Linked goals occur once in their original due month.
 static bool pendingCurrentMonth({
  required DateTime now,required DateTime startAt,required int day,
  required bool goalLinked,required bool alreadyPaid,
 }){
  if(alreadyPaid)return false;
  final due=goalLinked?DateTime(startAt.year,startAt.month,startAt.day):
   DateTime(now.year,now.month,
    day.clamp(1,DateTime(now.year,now.month+1,0).day));
  final first=DateTime(startAt.year,startAt.month,startAt.day);
  return due.year==now.year&&due.month==now.month&&
   due.isAfter(DateTime(now.year,now.month,now.day))&&
   !first.isAfter(due);
 }

 /// Use each saved budget's own user-selected threshold everywhere.
 static bool budgetThresholdVisible({
  required double spent,required double limit,
  required int alertPercent,required bool enabled,
 })=>enabled&&spent.isFinite&&limit.isFinite&&limit>0&&
  alertPercent>=1&&alertPercent<=100&&
  spent>=limit*alertPercent/100;

 /// Crossing detection prevents repeated alerts on successive expenses.
 /// The 100% limit is always a second milestone while alerts are enabled.
 static int crossedBudgetThreshold({
  required double previousSpent,required double spent,
  required double limit,required int alertPercent,required bool enabled,
 }) {
  if(!budgetThresholdVisible(spent:spent,limit:limit,
      alertPercent:alertPercent,enabled:enabled)||
      !previousSpent.isFinite)return 0;
  var crossed=0;
  for(final stage in <int>{alertPercent,100}.toList()..sort()){
   if(previousSpent<limit*stage/100&&spent>=limit*stage/100)crossed=stage;
  }
  return crossed;
 }

 static int budgetAlertStage(double spent,double limit){
  if(limit<=0)return 0;
  final percent=spent/limit*100;
  if(percent>=100)return 100;
  if(percent>=80)return 80;
  if(percent>=50)return 50;
  return 0;
 }
}

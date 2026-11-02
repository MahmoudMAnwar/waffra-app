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

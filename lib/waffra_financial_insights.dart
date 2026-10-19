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

 static int budgetAlertStage(double spent,double limit){
  if(limit<=0)return 0;
  final percent=spent/limit*100;
  if(percent>=100)return 100;
  if(percent>=80)return 80;
  if(percent>=50)return 50;
  return 0;
 }
}

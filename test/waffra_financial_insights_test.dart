import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_financial_insights.dart';

void main(){
 group('Financial insights / negative and boundary cases',(){
  test('forecasts remaining variable spend plus scheduled obligations',(){
   expect(WaffraFinancialInsights.projectedEndBalance(
    currentBalance:5000,variableExpensesSoFar:600,daysElapsed:10,daysInMonth:30,
    pendingRecurringIncome:1000,pendingRecurringExpense:500),4300);
  });
  test('does not divide by zero or forecast past current month',(){
   expect(WaffraFinancialInsights.projectedEndBalance(
    currentBalance:300,variableExpensesSoFar:800,daysElapsed:0,daysInMonth:30),300);
  });
  test('daily allowance never negative',(){
   expect(WaffraFinancialInsights.dailyAllowance(monthlyBudget:1000,spent:1100,daysRemaining:5),0);
   expect(WaffraFinancialInsights.dailyAllowance(monthlyBudget:1000,spent:600,daysRemaining:10),40);
   expect(WaffraFinancialInsights.dailyAllowance(monthlyBudget:1000,spent:600,daysRemaining:0),0);
  });
  test('comparison requires previous month data',(){
   expect(WaffraFinancialInsights.comparisonPercent(500,0),isNull);
   expect(WaffraFinancialInsights.comparisonPercent(120,100),20);
  });
  test('alert thresholds are inclusive and ordered',(){
   expect(WaffraFinancialInsights.budgetAlertStage(0,100),0);
   expect(WaffraFinancialInsights.budgetAlertStage(50,100),50);
   expect(WaffraFinancialInsights.budgetAlertStage(80,100),80);
   expect(WaffraFinancialInsights.budgetAlertStage(100,100),100);
   expect(WaffraFinancialInsights.budgetAlertStage(150,100),100);
   expect(WaffraFinancialInsights.budgetAlertStage(50,0),0);
  });
 });
}

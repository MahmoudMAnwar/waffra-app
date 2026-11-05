import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_monthly_budget_policy.dart';

void main(){
 const caps=[
  WaffraAccountMonthlyCap(budgetId:'groceries',accountId:'rajhi',capMinor:200000),
  WaffraAccountMonthlyCap(budgetId:'transport',accountId:'rajhi',capMinor:50000),
  WaffraAccountMonthlyCap(budgetId:'groceries',accountId:'snb',capMinor:80000),
 ];
 const spending=[
  WaffraAccountMonthlySpend(budgetId:'groceries',accountId:'rajhi',amountMinor:25000,monthIso:'2026-11'),
  WaffraAccountMonthlySpend(budgetId:'groceries',accountId:'snb',amountMinor:10000,monthIso:'2026-11'),
  WaffraAccountMonthlySpend(budgetId:'transport',accountId:'rajhi',amountMinor:5000,monthIso:'2026-11'),
  WaffraAccountMonthlySpend(budgetId:'unlinked',accountId:'rajhi',amountMinor:99000,monthIso:'2026-11'),
  WaffraAccountMonthlySpend(budgetId:'groceries',accountId:'snb',amountMinor:7000,monthIso:'2026-10'),
 ];
 test('M470 Rajhi view only shows its own monthly assigned caps and expenses',(){
  final result=WaffraAccountMonthlyBudgetPolicy.calculate(
   assignedCaps:caps,spending:spending,selectedAccountId:'rajhi',monthIso:'2026-11');
  expect(result.capMinor,250000);
  expect(result.spentMinor,30000);
  expect(result.remainingMinor,220000);
 });
 test('M470 All view sums each explicit account allocation once',(){
  final result=WaffraAccountMonthlyBudgetPolicy.calculate(
   assignedCaps:caps,spending:spending,monthIso:'2026-11');
  expect(result.capMinor,330000);
  expect(result.spentMinor,40000);
  expect(result.remainingMinor,290000);
 });
 test('M470 duplicated explicit account cap is rejected instead of inflated',(){
  expect(()=>WaffraAccountMonthlyBudgetPolicy.calculate(
   assignedCaps:[caps.first,caps.first],
   spending:const [],monthIso:'2026-11'),throwsStateError);
 });
 test('M470 invalid month and expense are rejected without default account',(){
  expect(()=>WaffraAccountMonthlyBudgetPolicy.calculate(
   assignedCaps:caps,spending:spending,monthIso:'2026-13'),throwsArgumentError);
  expect(()=>WaffraAccountMonthlyBudgetPolicy.calculate(
   assignedCaps:caps,spending:const [
    WaffraAccountMonthlySpend(budgetId:'groceries',accountId:'rajhi',
     amountMinor:-1,monthIso:'2026-11')],monthIso:'2026-11'),throwsStateError);
 });
}

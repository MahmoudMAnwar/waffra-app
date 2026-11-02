import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart' show WaffraNamedBudget;
import '../lib/waffra_financial_insights.dart';

void main(){
 test('M413 alert toggle persists independently from active budget',(){
  final b=WaffraNamedBudget(id:'b1',name:'Fuel',budget:1000,alertPercent:75,alertEnabled:false);
  final decoded=WaffraNamedBudget.fromJson(b.toJson());
  expect(decoded.budgetActive,isTrue);
  expect(decoded.alertEnabled,isFalse);
  expect(decoded.alertPercent,75);
  expect(decoded.copy(budgetActive:false).alertEnabled,isFalse);
  expect(decoded.copy(alertEnabled:true).budget,1000);
 });
 test('M413 historical budgets preserve legacy alerts',(){
  final raw=WaffraNamedBudget(id:'old',name:'Old',budget:400).toJson()..remove('alertEnabled');
  expect(WaffraNamedBudget.fromJson(raw).alertEnabled,isTrue);
  expect(()=>WaffraNamedBudget.fromJson({...raw,'alertEnabled':'false'}),throwsFormatException);
 });
 test('M413 Smart Insights respects 50, 75 and disabled thresholds',(){
  expect(WaffraFinancialInsights.budgetThresholdReached(500,1000,threshold:50),isTrue);
  expect(WaffraFinancialInsights.budgetThresholdReached(500,1000,threshold:75),isFalse);
  expect(WaffraFinancialInsights.budgetThresholdReached(1000,1000,threshold:50,enabled:false),isFalse);
 });
 test('M413 only warn when crossing a configured budget milestone',(){
  expect(WaffraFinancialInsights.newlyCrossedBudgetStage(490,510,1000,50),50);
  expect(WaffraFinancialInsights.newlyCrossedBudgetStage(510,520,1000,50),0);
  expect(WaffraFinancialInsights.newlyCrossedBudgetStage(900,1100,1000,50),100);
  expect(WaffraFinancialInsights.newlyCrossedBudgetStage(900,1100,1000,100),100);
  expect(WaffraFinancialInsights.newlyCrossedBudgetStage(1100,1200,1000,50),0);
 });
}

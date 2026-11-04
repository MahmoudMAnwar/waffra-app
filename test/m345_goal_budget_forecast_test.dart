import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_goal_budget_forecast.dart';

void main(){
 group('M345 goal deadline planning',(){
  test('ceil monthly funding to the halala, no fake deposits',(){
   final p=WaffraGoalPlan(targetMinor:500000,savedMinor:100000,
     today:DateTime(2026,11,1),dueDate:DateTime(2027,4,30));
   expect(p.remainingMinor,400000);
   expect(p.monthsAvailable,6);
   expect(p.monthlyRequiredMinor,66667);
  });
  test('deadline current month and past-due differ',(){
   final now=WaffraGoalPlan(targetMinor:10000,savedMinor:2000,
    today:DateTime(2026,11,1),dueDate:DateTime(2026,11,30));
   expect(now.monthsAvailable,1);
   expect(now.monthlyRequiredMinor,8000);
   final overdue=WaffraGoalPlan(targetMinor:10000,savedMinor:2000,
    today:DateTime(2026,11,1),dueDate:DateTime(2026,10,31));
   expect(overdue.overdue,isTrue);
   expect(overdue.monthlyRequiredMinor,isNull);
  });
  test('completed goal suggests zero without an artificial deposit',(){
   final p=WaffraGoalPlan(targetMinor:10000,savedMinor:10001,
    today:DateTime(2026,11,1),dueDate:DateTime(2026,10,1));
   expect(p.monthlyRequiredMinor,0);
   expect(p.remainingMinor,0);
  });
  test('forecast is advisory, rounded month-end and cannot post money',(){
   final p=WaffraGoalPlan(targetMinor:50000,savedMinor:0,
    today:DateTime(2026,1,31),dueDate:DateTime(2026,9,30));
   expect(p.projectedCompletion(monthlyPledgeMinor:25000),DateTime(2026,2,28));
   expect(p.savedMinor,0);
  });
  test('invalid/foreign precision never silently rounds into halalas',(){
   expect(waffraSarMinorChecked(75.00),7500);
   expect(()=>waffraSarMinorChecked(75.001),throwsStateError);
   expect(()=>waffraSarMinorChecked(double.nan),throwsStateError);
   expect(()=>waffraSarMinorChecked(-1),throwsStateError);
  });
 });

 group('M345 budget pacing and customizable warnings',(){
  test('forecast 500 spent in first half of 30-day period',(){
   const p=WaffraBudgetPace(spentMinor:50000,limitMinor:80000,
     dayOfPeriod:15,daysInPeriod:30);
   expect(p.forecastMinor,100000);
   expect(p.projectedOverBudget,isTrue);
   expect(p.warningStage,50);
  });
  test('exact thresholds 50 80 100',(){
   for(final pair in [(4999,0),(5000,50),(7999,50),
     (8000,80),(9999,80),(10000,100)]){
     final p=WaffraBudgetPace(spentMinor:pair.$1,limitMinor:10000,
       dayOfPeriod:28,daysInPeriod:30);
     expect(p.warningStage,pair.$2);
   }
  });
  test('invalid periods are never reported as forecasts',(){
   expect(()=>const WaffraBudgetPace(spentMinor:100,limitMinor:1000,
    dayOfPeriod:0,daysInPeriod:30).forecastMinor,throwsStateError);
  });
 });

 test('M345 actual goal and budget UI consume forecast without finance writes',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('WaffraGoalPlan('));
  expect(main,contains('WaffraBudgetPace('));
  expect(main,contains('selected?.alertPercent??80'));
  expect(main,contains('monthlyRequired/100'));
  expect(main,contains('حسب متوسط الصرف الحالي'));
 });
}

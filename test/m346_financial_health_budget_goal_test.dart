import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_practical_ledger_engine.dart';

void main(){
 test('M346 orphan budget link and unassigned category expense are review-only',(){
   final records=[
    WaffraPracticalEntry(id:'unassigned',title:'Gas',
      category:'سيارة / بنزين',amount:75,income:false,
      date:DateTime(2026,11,1),unassignedNamedBudget:true),
    WaffraPracticalEntry(id:'deleted-budget',title:'Lunch',
      category:'مطاعم',amount:20,income:false,
      date:DateTime(2026,11,1),orphanBudgetLink:true),
    WaffraPracticalEntry(id:'income',title:'Salary',category:'رواتب',
      amount:5000,income:true,date:DateTime(2026,11,1)),
   ];
   final issues=WaffraDataHealth.inspect(records);
   expect(issues.where((v)=>v.kind==WaffraHealthIssueKind.unassignedNamedBudget)
     .map((v)=>v.entryId),['unassigned']);
   expect(issues.where((v)=>v.kind==WaffraHealthIssueKind.orphanBudgetLink)
     .map((v)=>v.entryId),['deleted-budget']);
   expect(records[0].amount,75); // read-only, never auto post
 });
 test('M346 no false warning for generic expenses without a named budget',(){
   final issues=WaffraDataHealth.inspect([
    WaffraPracticalEntry(id:'normal',title:'Fare',category:'نقل',
      amount:30,income:false,date:DateTime(2026,11,1)),
   ]);
   expect(issues,isEmpty);
 });
 test('M346 real Tools health UI consumes Home budget IDs and goal snapshots',(){
   final app=File('lib/main.dart').readAsStringSync();
   final smart=File('lib/waffra_smart_features.dart').readAsStringSync();
   final tools=File('lib/waffra_practical_tools_page.dart').readAsStringSync();
   expect(app,contains('unassignedNamedBudget:!e.income&&e.budgetId==null'));
   expect(app,contains('orphanBudgetLink:e.budgetId!=null'));
   expect(smart,contains('goalOverallocated:'));
   expect(tools,contains('WaffraHealthIssueKind.orphanBudgetLink'));
   expect(tools,contains('Goal savings exceed recorded net cash'));
 });
}

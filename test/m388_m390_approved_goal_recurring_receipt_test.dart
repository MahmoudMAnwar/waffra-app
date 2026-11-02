import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_financial_planning_engine.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M388: open-ended goal is saved and restored with no fabricated target',(){
  final goal=SavingGoal(
   id:'unlimited-savings-1',name:'ادخار مفتوح',target:0,saved:1250.50);
  final serialized=jsonEncode(goal.toJson());
  final restored=SavingGoal.fromJson(
   Map<String,dynamic>.from(jsonDecode(serialized) as Map));
  expect(restored.id,goal.id);
  expect(restored.target,0);
  expect(restored.saved,1250.50);
  expect(restored.dueDate,isNull);
  expect(waffraGoalWalletBalance([restored]),1250.50);
  expect(waffraAvailableCash(<MoneyEntry>[],[restored]),0);
  expect(restored.copy(saved:1500).target,0);
 });

 test('M388: finance health audit counts saved funds for a zero-target goal',(){
  final result=GoalWalletHealthAudit.inspect(250000,[
   const GoalAmountEvidence('unlimited',0,65000),
  ]);
  expect(result.reservedMinor,65000);
  expect(result.availableMinor,185000);
  expect(result.issues, isEmpty);
 });

 test('M389: duplicate goal uses independent identity and starts with zero savings',(){
  final source=File('lib/main.dart').readAsStringSync();
  final dialog=source.split('Future<void> goalDialog(').last
    .split('/// Release an earmark').first;
  expect(dialog,contains('{SavingGoal? duplicate,bool openEnded=false})'));
  expect(dialog,contains('SavingGoal(id:newId()'));
  expect(dialog,contains('target:noTarget?0.0:n!,saved:0'));
  expect(dialog,contains('duplicate.target<=0'));
  expect(dialog,contains('noTarget=openEnded'));
  expect(dialog,contains('requestedRecurring=await _confirmGoalDueRecurringLink(g)'));
  expect(dialog,contains('if(requestedRecurring&&mounted)'));
  expect(dialog,contains('this._ensureLinkedRecurringForGoal(g)'));
  expect(dialog,isNot(contains('target:duplicate.target,saved:duplicate.saved')));
 });

 test('M389: recurring duplicate is new, editable, and cannot inherit linked goal ID',(){
  final source=File('lib/main.dart').readAsStringSync();
  final dialog=source.split('Future<void> recurringDialog(').last
    .split('DateTime nextRecurringDue(').first;
  expect(dialog,contains('RecurringBill? duplicate'));
  expect(dialog,contains('initial?.title??duplicate?.title'));
  expect(dialog,contains('initial?.id??newId()'));
  expect(dialog,contains('linkedGoalId:initial?.linkedGoalId'));
  expect(dialog,contains('if(initial==null){recurring.add(r);}')
   ,reason:'Copied recurring must be a separate record rather than editing source');
 });

 test('M389: Goals/Recurring + menus show approved choices instead of direct sheet',(){
  final source=File('lib/main.dart').readAsStringSync();
  final menu=source.split('if(!accountOpened&&(tab==0||tab==1||tab==3||tab==4||goalsOpened))').last
    .split('// The notice reserves real layout').first;
  for(final label in <String>[
   'إضافة هدف جديد','ادخار مفتوح بدون مستهدف','تكرار هدف موجود',
   'إضافة عملية متكررة','تكرار عملية متكررة موجودة']){
   expect(menu,contains(label));
  }
  expect(menu,contains('expanded:addFabExpanded'));
  expect(menu,contains('setState(()=>addFabExpanded=!addFabExpanded)'));
  expect(menu,isNot(contains(
   'if(goalsOpened||tab==3){unawaited(_launchAddAction(()=>goalDialog()))')));
  expect(menu,isNot(contains(
   'if(tab==4){unawaited(_launchAddAction(()=>recurringDialog()))')));
 });

 test('M388: open-ended goal never divided by zero or marked achieved',(){
  final source=File('lib/main.dart').readAsStringSync();
  final card=source.split('Widget goalsPage(){').last
   .split('Widget recurringPage(){').first;
  expect(card,contains('g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0)'));
  expect(card,contains('if(g.target>0&&g.saved>=g.target)'));
  expect(card,contains('if(g.target<=0||g.saved<g.target)'));
  expect(card,contains('g.target>0&&g.saved>=g.target'));
  expect(card,contains("waffraIsEnglish?'Open-ended savings':'ادخار مفتوح'"));
  final edit=File('lib/waffra_goal_recurring_actions.part.dart').readAsStringSync();
  expect(edit,contains('if(deadline==null||goal.target<=0)'));
  expect(edit,contains('target:noTarget?0.0:v!'));
  expect(edit,contains('if(deadline==null||goal.target<=0)'));
 });

 test('M390: restored receipt references open the same existing gallery',(){
  final source=File('lib/main.dart').readAsStringSync();
  final list=source.split('Widget tile(MoneyEntry e){').last
    .split('String get greeting').first;
  final home=source.split('Widget compactTransaction(MoneyEntry entry){').last
    .split('Widget dashboard(){').first;
  expect(list,contains('onTap:()=>showReceipt(e.receiptPath!)'));
  expect(home,contains('onTap:()=>showReceipt(entry.receiptPath!)'));
  expect(source,contains('Future<void> showReceipt(String encoded,{int initialIndex=0})'));
  expect(list,isNot(contains('File(')));
  expect(home,isNot(contains('File(')));
  expect(waffraReceiptPaths(jsonEncode(['old.jpg','old2.jpg'])),
    ['old.jpg','old2.jpg']);
 });

 testWidgets('M390: clipped badge is tappable with 48dp target in Arabic and English',
    (tester) async {
  for(final english in [false,true]){
   var opened=0;
   await tester.pumpWidget(MaterialApp(
    home:Directionality(
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     child:Scaffold(body:Center(child:WaffraReceiptCornerAction(
      count:2,english:english,onTap:()=>opened++))))));
   expect(find.text('2'),findsOneWidget);
   expect(find.byIcon(Icons.attach_file_rounded),findsOneWidget);
   expect(tester.getSize(find.byType(WaffraReceiptCornerAction)),const Size(48,48));
   await tester.tap(find.byType(WaffraReceiptCornerAction));
   await tester.pump();
   expect(opened,1);
   expect(tester.takeException(),isNull);
  }
 });
}

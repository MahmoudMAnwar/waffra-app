import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

MoneyEntry _settled({String notes='goal_wallet_minor=200000;current_cash_minor=300000'}) =>
 MoneyEntry(
  id:'rec_goal_2026_11',title:'استحقاق سيارة',
  category:'مطاعم وكافيهات / مطاعم شعبية',
  amount:5000,income:false,date:DateTime(2026,11,12),
  sourceType:'goal_due',goalWalletPaidMinor:200000,notes:notes,
 );

void main(){
 test('M665.7 5000 total = 2000 saved wallet + 3000 live bank debit',(){
  final e=_settled();
  expect(e.amount,5000);
  expect(e.goalWalletPaidMinor,200000);
  expect(waffraGoalDueCashMinor(e),300000);
  expect(waffraAvailableCash([e],[]),-3000);
  expect(MoneyEntry.fromJson(e.toJson()).goalWalletPaidMinor,200000);
 });

 test('M665.7 hide only old technical goal notes, keep user-owned notes',(){
  expect(waffraGoalDueVisibleNotes(_settled()),isEmpty);
  expect(waffraGoalDueVisibleNotes(
   _settled(notes:'دفعت باقي مبلغ السيارة')), 'دفعت باقي مبلغ السيارة');
  expect(waffraGoalDueVisibleNotes(
   MoneyEntry(id:'manual',title:'manual',category:'other',amount:2,
    income:false,date:DateTime(2026),notes:'user notes')), 'user notes');
 });

 test('M665.7 paid goal due is purposeful in all financial presentations',(){
  final main=File('lib/main.dart').readAsStringSync();
  final details=main.substring(
   main.indexOf('class WaffraTransactionDetailsDialog'),
   main.indexOf('class HomeScreen extends StatefulWidget'));
  expect(details,contains('waffraGoalDueVisibleNotes(entry)'));
  expect(details,contains("Key('m665-goal-due-details-breakdown')"));
  expect(details,contains('waffraGoalDueCashMinor(entry)/100'));
  expect(details,contains("'استحقاق هدف'"));
  expect(details,contains("showBudgetInfo&&entry.sourceType!='goal_due'"));
  final home=main.substring(main.indexOf(' Widget compactTransaction('),
   main.indexOf(' Widget _m549HomeFinanceAction('));
  expect(home,contains('waffraGoalDueCashMinor(entry)/100'));
  expect(home,contains('entry.goalWalletPaidMinor/100'));
  expect(home,contains("'إجمالي الاستحقاق'"));
  expect(home,contains("'استحقاق هدف'"));
  expect(home,contains('Icons.flag_outlined'));
  final pdf=main.substring(main.indexOf(' Future<void> exportEntriesPdf('),
   main.indexOf(' Future<void> _deleteVerifiedEntry('));
  expect(pdf,contains("english?'Goal due':'استحقاق هدف'"));
  expect(pdf,contains('waffraGoalDueCashMinor(e)/100'));
  expect(pdf,contains('e.goalWalletPaidMinor/100'));
  expect(pdf,isNot(contains("goal_wallet_minor=")));
 });

 test('M665.7 recurring goal payment shows paid split, not zero saved progress',(){
  final main=File('lib/main.dart').readAsStringSync();
  final start=main.indexOf(' Widget recurringPage(){');
  final end=main.indexOf('   if(recurring.isEmpty)Padding',start);
  final card=main.substring(start,end);
  expect(card,contains('paidGoalDue=goal!=null&&paid.length==1?paid.single:null'));
  expect(card,contains('if(paidGoalDue!=null)...['));
  expect(card,contains('waffraGoalDueCashMinor(paidGoalDue)/100'));
  expect(card,contains('paidGoalDue.goalWalletPaidMinor/100'));
  expect(card,contains("'استحقاق هدف مدفوع'"));
  expect(card,contains(']else if(goal!=null)...['));
  expect(card,contains("goal!=null?Icons.flag_outlined"));
 });

 test('M689 goal action sheet retains fund/edit/release/delete/active',(){
  final main=File('lib/main.dart').readAsStringSync();
  final start=main.indexOf(' Future<void> _m689GoalActions(');
  final end=main.indexOf(' Widget goalsPage(){',start);
  final quick=main.substring(start,end);
  expect(quick,contains('SwitchListTile.adaptive('));
  expect(quick,contains("Key('waffra-goal-active-switch-'+g.id)"));
  expect(quick,contains('setGoalActive(g,enabled)'));
  expect(quick,contains("fundGoal(g)"));
  expect(quick,contains("_handleGoalCardAction(g,'edit')"));
  expect(quick,contains("_handleGoalCardAction(g,'release')"));
  expect(quick,contains("_handleGoalCardAction(g,'delete')"));
  final goals=main.substring(end,main.indexOf(' Future<void> recurringDialog(',end));
  expect(goals,contains("Key('m689-goal-card-'+g.id)"));
  expect(goals,isNot(contains("'View':'عرض'")));
 });

 test('M665.7 linked due edit explains without changing finance; standalone still editable',(){
  final main=File('lib/main.dart').readAsStringSync();
  final handlerStart=main.indexOf(' Future<void> _handleRecurringCardAction(');
  final handlerEnd=main.indexOf(' Widget recurringPage(){',handlerStart);
  expect(handlerStart,greaterThanOrEqualTo(0));
  expect(handlerEnd,greaterThan(handlerStart));
  final handler=main.substring(handlerStart,handlerEnd);
  expect(handler,contains("if(r.linkedGoalId!=null)"));
  expect(handler,contains('_m665ExplainLinkedGoalEdit()'));
  expect(handler,contains('await recurringDialog(initial:r)'));
  final dialog=main.substring(main.indexOf(' Future<void> recurringDialog('),
   main.indexOf(' DateTime nextRecurringDue('));
  expect(dialog,contains("if(initial?.linkedGoalId!=null)"));
  expect(dialog,contains('await _m665ExplainLinkedGoalEdit();'));
  final paidEditor=main.substring(main.indexOf(' Future<void> entrySheet('),
   main.indexOf(' Future<void> transactionActions('));
  expect(paidEditor,contains("if(initial?.sourceType=='goal_due')"));
  expect(paidEditor,contains('_m665ExplainLinkedGoalEdit(paid:true)'));
  final actions=main.substring(main.indexOf(' Future<void> transactionActions('),
   main.indexOf(' Widget _transactionActionTile('));
  expect(actions,contains("if(entry.sourceType=='goal_due')"));
  expect(actions,contains('await entrySheet(initial:entry)'));
  final card=main.substring(main.indexOf(' Widget recurringPage(){'),
   main.indexOf('   if(recurring.isEmpty)Padding',
    main.indexOf(' Widget recurringPage(){')));
  expect(card,contains("key:Key('m665-recurring-edit-'+r.id)"));
  // In M689 the linked goal may only be edited through its own verified route.
  expect(card,contains("_handleGoalCardAction(goal,'edit')"));
  expect(card,contains('waffraGoalDueCashMinor(paidGoalDue)/100'));
  expect(card,contains("Key('m689-due-card-'+r.id)"));
  expect(card,isNot(contains("PageStorageKey<String>('waffra-recurring-quick-actions-'")));
  // An orphaned linked due is still controlled by the goal editor; only
  // a standalone recurring item can open a direct edit sheet.
 });

 testWidgets('M665.7 widget shows labelled wallet and bank, never tech notes/restaurant',
  (tester)async{
   final due=_settled();
   await tester.pumpWidget(MaterialApp(
    home:Scaffold(body:WaffraTransactionDetailsDialog(
     entry:due,onClose:(){}))));
   await tester.pump();
   expect(find.byKey(const Key('m665-goal-due-details-breakdown')),
    findsOneWidget);
   expect(find.text('استحقاق هدف'),findsWidgets);
   // WaffraText intentionally composes an inner Text, so Flutter's
   // text finder observes both wrapper and child for one visual label.
   final breakdown=find.byKey(const Key('m665-goal-due-details-breakdown'));
   expect(find.descendant(of:breakdown,
    matching:find.text('من محفظة الهدف')),findsWidgets);
   expect(find.descendant(of:breakdown,
    matching:find.text('المخصوم من الحساب المالي')),findsWidgets);
   expect(find.text('مطاعم وكافيهات / مطاعم شعبية'),findsNothing);
   expect(find.textContaining('goal_wallet_minor'),findsNothing);
  });


 test('M665.7 old goal due never becomes restaurant category in Smart/PDF rankings',(){
  final payment=_settled();
  final dinner=MoneyEntry(id:'dinner',title:'عشاء',category:payment.category,
   amount:150,income:false,date:DateTime(2026,11,12));
  expect(waffraEntryReportCategory(payment),'استحقاق هدف');
  expect(waffraEntryReportCategory(dinner),dinner.category);
  final report=waffraSmartChartData([payment,dinner],DateTime(2026,11,13));
  final summary=Map<String,double>.fromEntries(report.topCategories);
  expect(summary['استحقاق هدف'],5000);
  expect(summary['مطاعم وكافيهات / مطاعم شعبية'],150);
  final pdf=File('lib/main.dart').readAsStringSync();
  final export=pdf.substring(pdf.indexOf(' Future<void> exportEntriesPdf('),
    pdf.indexOf(' Future<void> _deleteVerifiedEntry('));
  expect(export,contains('final label=waffraEntryReportCategory(e);'));
  expect(export,contains('categoryTotals[label]=(categoryTotals[label]??0)+e.amount'));
 });

}

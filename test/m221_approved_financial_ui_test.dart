import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_financial_tools.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M221 user-created category provenance survives JSON and edits', () {
  final user=BudgetCategory(id:'user-1',name:'مضاف مني',icon:'category',
   color:0xFF087A54,income:false,origin:'user');
  final restored=BudgetCategory.fromJson(user.toJson());
  expect(restored.isUserAdded,isTrue);
  expect(restored.copy(name:'بعد التعديل').isUserAdded,isTrue);
  expect(restored.toJson()['origin'],'user');
 });

 test('M221 legacy and detected categories never falsely claim user origin', () {
  const raw=<String,dynamic>{
   'id':'builtin','name':'افتراضي','icon':'category',
   'color':0xFF087A54,'income':false,
  };
  expect(BudgetCategory.fromJson(raw).isUserAdded,isFalse);
  expect(BudgetCategory.fromJson({...raw,'origin':'detected'}).isUserAdded,isFalse);
  expect(BudgetCategory.fromJson({...raw,'origin':'invalid'}).origin,'system');
 });

 test('M221 subscriptions require two different months and consistent sums', () {
  final items=[
   WaffraCalendarItem(DateTime(2026,7,11),'Service A',49,false),
   WaffraCalendarItem(DateTime(2026,8,11),'Service A',49,false),
   WaffraCalendarItem(DateTime(2026,8,12),'Single B',20,false),
   WaffraCalendarItem(DateTime(2026,9,12),'Variable C',60,false),
   WaffraCalendarItem(DateTime(2026,10,12),'Variable C',140,false),
   WaffraCalendarItem(DateTime(2026,9,5),'Income D',100,true),
  ];
  final matches=detectWaffraSubscriptions(items);
  expect(matches.length,1);
  expect(matches.single.title,'Service A');
  expect(matches.single.estimatedMonthly,49);
 });

 testWidgets('M221 financial tools subscriptions empty state uses real data',
     (tester) async {
  await tester.pumpWidget(const MaterialApp(home:WaffraSubscriptionScreen(
   items:[],english:false,
  )));
  expect(find.text('كشف الاشتراكات'),findsOneWidget);
  expect(find.text('لا توجد اشتراكات محتملة حاليًا'),findsOneWidget);
  expect(find.text('لا توجد مصروفات متكررة مسجلة'),findsOneWidget);
  expect(find.text('0.00 ريال'),findsWidgets);
 });

 testWidgets('M221 subscription suggestion opens functional recurring form',
     (tester) async {
  WaffraSubscriptionCandidate? requested;
  final rows=[
   WaffraCalendarItem(DateTime(2026,7,4),'Cloud service',29,false),
   WaffraCalendarItem(DateTime(2026,8,4),'Cloud service',29,false),
  ];
  await tester.pumpWidget(MaterialApp(home:WaffraSubscriptionScreen(
   items:rows,english:false,
   onAddRecurring:(candidate)async{requested=candidate;},
  )));
  await tester.ensureVisible(find.text('مراجعة وإضافة'));
  await tester.tap(find.text('مراجعة وإضافة'));
  await tester.pump();
  expect(requested?.title,'Cloud service');
  expect(requested?.estimatedMonthly,29);
 });

 testWidgets('M221 ignored subscription hides only in current screen',
     (tester) async {
  final items=[
   WaffraCalendarItem(DateTime(2026,7,4),'Service C',32,false),
   WaffraCalendarItem(DateTime(2026,8,4),'Service C',32,false),
  ];
  await tester.pumpWidget(MaterialApp(home:WaffraSubscriptionScreen(
   items:items,english:false,
   onAddRecurring:(candidate)async{},
  )));
  await tester.ensureVisible(find.text('تجاهل'));
  await tester.tap(find.text('تجاهل'));
  await tester.pump();
  expect(find.text('Service C'),findsNothing);
  expect(find.text('لا توجد اشتراكات محتملة حاليًا'),findsOneWidget);
 });

 testWidgets('M221 English subscription screen remains localizable',
     (tester) async {
  await tester.pumpWidget(const MaterialApp(home:WaffraSubscriptionScreen(
   items:[],english:true,
  )));
  expect(find.text('Subscription insights'),findsOneWidget);
  expect(find.text('No patterns detected yet'),findsOneWidget);
 });

 testWidgets('M221 registered recurring payments excluded from suggestions',
     (tester) async {
  final rows=[
   WaffraCalendarItem(DateTime(2026,7,4),'Service R',49,false),
   WaffraCalendarItem(DateTime(2026,8,4),'Service R',49,false),
   WaffraCalendarItem(DateTime(2026,10,4),'Service R',49,false,scheduled:true),
  ];
  await tester.pumpWidget(MaterialApp(home:WaffraSubscriptionScreen(
   items:rows,english:false,
  )));
  expect(find.text('لا توجد اشتراكات محتملة حاليًا'),findsOneWidget);
  expect(find.text('Service R'),findsOneWidget);
 });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_today_picker.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M374 attached image action only lives in transaction details', () {
  final code=File('lib/main.dart').readAsStringSync();
  final outer=code.substring(
   code.indexOf('Future<void> transactionActions('),
   code.indexOf('Widget _transactionActionTile(',code.indexOf('Future<void> transactionActions(')));
  expect(outer,contains('View details'));
  expect(outer,isNot(contains('View attached images')));
  expect(outer,isNot(contains("case 'receipt':")));
  expect(code,contains('if(onViewReceipt!=null)'));
  expect(code,contains('waffraReceiptPaths(entry.receiptPath).isNotEmpty'));
 });

 testWidgets('M374 receipt action opens only from details with attachments', (tester) async {
  var opened=0;
  MoneyEntry entry(String? receipt)=>MoneyEntry(
   id:'m374',title:'حوالة صادرة',category:'تحويلات',
   amount:60,income:false,date:DateTime(2026,11,2),receiptPath:receipt);
  Future<void> show(MoneyEntry e,VoidCallback? onReceipt)async{
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:
    WaffraTransactionDetailsDialog(entry:e,onClose:(){},onViewReceipt:onReceipt))));
   await tester.pumpAndSettle();
  }
  await show(entry(null),null);
  expect(find.text('عرض المرفقات'),findsNothing);
  await show(entry('receipt.jpg'),()=>opened++);
  expect(find.text('عرض المرفقات'),findsOneWidget);
  await tester.ensureVisible(find.text('عرض المرفقات'));
  await tester.tap(find.text('عرض المرفقات'));
  expect(opened,1);
 });

 testWidgets('M374 undo and close have separate hit targets and callbacks', (tester)async{
  var undos=0,dismisses=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(child:
   SizedBox(width:320,child:Material(child:WaffraNoticeContent(
    notice:WaffraNoticeData(
     text:'تم تعديل المعاملة',kind:WaffraSnackKind.success,
     duration:const Duration(seconds:6),requireDismissal:false,
     actionLabel:'تراجع',onAction:()=>undos++),
    onDismiss:()=>dismisses++)))))));
  await tester.pumpAndSettle();
  final undo=find.byKey(const Key('waffra-notice-undo'));
  final dismiss=find.byKey(const Key('waffra-notice-dismiss'));
  expect(undo,findsOneWidget);
  expect(dismiss,findsOneWidget);
  expect(tester.getRect(undo).overlaps(tester.getRect(dismiss)),isFalse);
  await tester.tap(dismiss);
  expect(dismisses,1);
  expect(undos,0);
  await tester.tap(undo);
  expect(dismisses,2);
  expect(undos,1);
 });

 testWidgets('M374 today is INSIDE the calendar dialog', (tester)async{
  DateTime? result;
  final today=DateUtils.dateOnly(DateTime.now());
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>
   Scaffold(body:TextButton(onPressed:()async{
    result=await waffraPickDateWithToday(
     context:context,initialDate:today.subtract(const Duration(days:1)),
     firstDate:today.subtract(const Duration(days:3)),
     lastDate:today.add(const Duration(days:3)));
   },child:const Text('Calendar'))))));
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  final todayAction=find.byKey(const Key('waffra-datepicker-today'));
  expect(find.byType(AlertDialog),findsOneWidget);
  expect(find.ancestor(of:todayAction,matching:find.byType(AlertDialog)),findsOneWidget);
  expect(find.byKey(const Key('waffra-datepicker-confirm')),findsOneWidget);
  expect(find.byKey(const Key('waffra-datepicker-cancel')),findsOneWidget);
  await tester.tap(todayAction);
  await tester.pumpAndSettle();
  expect(result,today);
 });

 test('M374 report actions have matched width and reusable flow',(){
  final code=File('lib/main.dart').readAsStringSync();
  final from=code.indexOf('waffra-pdf-open-action');
  final to=code.indexOf('waffra-pdf-share-action',from);
  expect(from,greaterThan(-1));
  expect(to,greaterThan(from));
  final report=code.substring(from-230,to+550);
  expect(report,contains('crossAxisAlignment:CrossAxisAlignment.stretch'));
  expect(report,contains('SizedBox(height:10)'));
  expect(report,contains('Printing.sharePdf(bytes:bytes,filename:fileName)'));
 });
}

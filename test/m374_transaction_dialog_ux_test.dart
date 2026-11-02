import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_today_picker.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M374 attachment button is not duplicated in quick actions', () {
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('Future<void> transactionActions(MoneyEntry entry)');
  final end=source.indexOf('Widget _transactionActionTile(',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final quickActions=source.substring(start,end);
  expect(quickActions,contains('View details'));
  expect(quickActions,isNot(contains('View attached images')));
  expect(quickActions,isNot(contains("case 'receipt':")));
  expect(source,contains('if(onViewReceipt!=null)'));
 });

 testWidgets('M374 attachments appear inside details only when available',
     (tester) async {
  var opened=0;
  MoneyEntry item()=>MoneyEntry(
   id:'m374',title:'حوالة صادرة',category:'تحويلات',
   amount:60,income:false,date:DateTime(2026,11,2));
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   WaffraTransactionDetailsDialog(
    entry:item(),onClose:(){},onViewReceipt:null))));
  expect(find.byIcon(Icons.photo_library_outlined),findsNothing);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   WaffraTransactionDetailsDialog(
    entry:item(),onClose:(){},onViewReceipt:()=>opened++))));
  final open=find.byIcon(Icons.photo_library_outlined);
  expect(open,findsOneWidget);
  await tester.ensureVisible(open);
  await tester.tap(open);
  expect(opened,1);
 });

 testWidgets('M374 close and undo are separate, independently working controls',
     (tester) async {
  var closed=0,undone=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
   child:SizedBox(width:320,child:Material(
    child:WaffraNoticeContent(
     notice:WaffraNoticeData(text:'تم تعديل المعاملة',
      kind:WaffraSnackKind.success,requireDismissal:true,
      duration:const Duration(seconds:5),
      actionLabel:'تراجع',onAction:()=>undone++),
     onDismiss:()=>closed++),
   ))))));
  final close=find.byIcon(Icons.close_rounded);
  final undo=find.byKey(const Key('waffra-snackbar-action'));
  expect(close,findsOneWidget);
  expect(undo,findsOneWidget);
  expect(tester.getRect(close).overlaps(tester.getRect(undo)),isFalse);
  expect(tester.getSize(find.byKey(const Key('waffra-snackbar-close'))).height,
   greaterThanOrEqualTo(48));
  expect(tester.getSize(undo).height,greaterThanOrEqualTo(48));
  await tester.tap(close);
  expect(closed,1);
  expect(undone,0);
  await tester.tap(undo);
  expect(closed,2);
  expect(undone,1);
 });

 testWidgets('M374 Today stays inside dialog and needs confirmation', (tester) async {
  DateTime? saved;
  final today=DateUtils.dateOnly(DateTime.now());
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(ctx)=>
   Scaffold(body:TextButton(onPressed:() async {
    saved=await waffraPickDateWithToday(context:ctx,
     initialDate:today.subtract(const Duration(days:2)),
     firstDate:today.subtract(const Duration(days:4)),
     lastDate:today.add(const Duration(days:4)));
   },child:const Text('Open calendar'))))));
  await tester.tap(find.text('Open calendar'));
  await tester.pumpAndSettle();
  final todayButton=find.byKey(const Key('waffra-datepicker-today'));
  final confirm=find.byKey(const Key('waffra-datepicker-confirm'));
  expect(todayButton,findsOneWidget);
  expect(find.ancestor(of:todayButton,matching:find.byType(Dialog)),
   findsOneWidget);
  await tester.tap(todayButton);
  await tester.pumpAndSettle();
  expect(saved,isNull,reason:'Today selection does not save a financial edit');
  await tester.tap(confirm);
  await tester.pumpAndSettle();
  expect(saved,today);
 });

 test('M374 PDF open and share have responsive matching action widths', () {
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf("key:const Key('waffra-report-open')");
  final share=source.indexOf("key:const Key('waffra-report-share')",start);
  expect(start,greaterThanOrEqualTo(0));
  expect(share,greaterThan(start));
  final section=source.substring(start,source.indexOf('}catch(e,st)',share));
  expect(section,contains('if(limits.maxWidth<300)'));
  expect(section,contains('Expanded(child:openButton())'));
  expect(section,contains('Expanded(child:shareButton())'));
  expect(section,contains('Printing.sharePdf(bytes:bytes,filename:fileName)'));
 });
}

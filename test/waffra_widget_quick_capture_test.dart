import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';

void main(){
 setUp((){
  SharedPreferences.setMockInitialValues({
   'entries':'[]',
   'waffra_sms_hashes_v1':<String>[],
   'waffra_language':'ar',
   'waffra_hide_amounts':false,
  });
 });

 test('Waffra Android widget remains one cell and never abbreviates numbers',(){
  final source=File('.github/workflows/android.yml').readAsStringSync();
  expect(source,contains('android:targetCellWidth="1"'));
  expect(source,contains('android:targetCellHeight="1"'));
  final dart=File('lib/main.dart').readAsStringSync();
  expect(dart,contains("currency:waffraIsEnglish?'SAR':'ريال'"));
  expect(dart,contains('formatWaffraMoney((income-expense)/100)'));
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  expect(native,contains('WaffraQuickActivity::class.java'));
 });

 testWidgets('Bank SMS is analyzed as soon as user pastes without an Analyze button',(tester)async{
  await tester.binding.setSurfaceSize(const Size(430,920));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const WaffraWidgetCaptureApp());
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-widget-bank-message')),findsOneWidget);
  await tester.enterText(find.byKey(const Key('waffra-widget-bank-message')),
   'شراء PoS\nالمبلغ: 125.50 SAR\nلدى متجر');
  await tester.pump(const Duration(milliseconds:480));
  await tester.pump();
  expect(find.textContaining('المكتشفة: 1'),findsOneWidget);
  expect(find.text('تأكيد إضافة العمليات'),findsOneWidget);
  expect(find.text('تحليل الرسالة'),findsNothing);
 });

 testWidgets('Only confirmation writes an SMS transaction and prevents duplicates',(tester)async{
  final testLockDirectory=await Directory.systemTemp.createTemp('waffra-widget-lock-test-');
  addTearDown(()async{
   if(await testLockDirectory.exists())await testLockDirectory.delete(recursive:true);
  });
  await tester.binding.setSurfaceSize(const Size(430,920));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(WaffraWidgetCaptureApp(testWriterDirectory:testLockDirectory));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('waffra-widget-bank-message')),
   'شراء PoS\nالمبلغ: 125.50 SAR\nلدى متجر');
  await tester.pump(const Duration(milliseconds:480));
  final p=await SharedPreferences.getInstance();
  expect(jsonDecode(p.getString('entries')??'[]'),isEmpty);
  await tester.ensureVisible(find.text('تأكيد إضافة العمليات'));
  await tester.tap(find.text('تأكيد إضافة العمليات'));
  await tester.pump(const Duration(milliseconds:250));
  await tester.pump(const Duration(milliseconds:1350));
  final saved=jsonDecode(p.getString('entries')??'[]') as List;
  expect(saved.length,1);
  expect((saved.first['amount'] as num).toDouble(),125.5);
  expect(saved.first['income'],false);
 });
}

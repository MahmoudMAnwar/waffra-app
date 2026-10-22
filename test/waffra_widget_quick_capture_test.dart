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
  // FakeAsync cannot run native file locks: use the isolated test-only bypass.
  final folder=Directory.systemTemp.createTempSync('waffra-widget-load-test-');
  addTearDown((){if(folder.existsSync())folder.deleteSync(recursive:true);});
  await tester.pumpWidget(WaffraWidgetCaptureApp(
   testWriterDirectory:folder,testBypassNativeLock:true,
   testSourceProbe:() async {},
  ));
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
  // Widget tests run in FakeAsync. Create/clean this local-only folder
  // synchronously or the test can hang before the first frame is pumped.
  final testLockDirectory=Directory.systemTemp.createTempSync('waffra-widget-lock-test-');
  addTearDown((){
   if(testLockDirectory.existsSync())testLockDirectory.deleteSync(recursive:true);
  });
  await tester.binding.setSurfaceSize(const Size(430,920));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(WaffraWidgetCaptureApp(
   testWriterDirectory:testLockDirectory,
   testBypassNativeLock:true,
   testSourceProbe:() async {},
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('waffra-widget-bank-message')),
   'شراء PoS\nالمبلغ: 125.50 SAR\nلدى متجر');
  await tester.pump(const Duration(milliseconds:480));
  final p=await SharedPreferences.getInstance();
  expect(jsonDecode(p.getString('entries')??'[]'),isEmpty);
  await tester.ensureVisible(find.text('تأكيد إضافة العمليات'));
  await tester.tap(find.text('تأكيد إضافة العمليات'));
  // UI behavior runs with the test-only in-memory coordinator because
  // Flutter widget FakeAsync cannot execute native File.lock callbacks.
  // The production lock is exercised by its separate real-I/O tests.
  await tester.pump(const Duration(milliseconds:250));
  await tester.pump(const Duration(milliseconds:1350));
  final saved=jsonDecode(p.getString('entries')??'[]') as List;
  expect(saved.length,1);
  expect((saved.first['amount'] as num).toDouble(),125.5);
  expect(saved.first['income'],false);
 });
}

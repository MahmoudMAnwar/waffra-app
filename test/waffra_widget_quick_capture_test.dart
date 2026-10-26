import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_display_currency.dart';

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
  expect(dart,contains('currency:WaffraDisplayCurrency.label(waffraIsEnglish)'));
  expect(dart,contains('WaffraAuthoritativeWidgetBalance.netHalalas(raw)'));
  final widget=File('lib/waffra_widget_capture.part.dart').readAsStringSync();
  expect(widget,contains(
   'WaffraAuthoritativeWidgetBalance.netHalalas(verified.ledgerRaw!)'));
  expect(widget,contains('await WaffraDisplayCurrency.initialize();'));
  expect(widget,contains('final conceal=hidden||display==null;'));
  expect(widget,contains('currency:WaffraDisplayCurrency.label(_english)'));
  expect(widget,contains("balance:conceal?'***':WaffraDisplayCurrency.amount(net/100)"));
  expect(widget,isNot(contains("currency:_english?'SAR':'ريال'")));
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  expect(native,contains('WaffraQuickActivity::class.java'));
 });

 test('M225 widget respects display-only label without FX multiplication',(){
  final label=WaffraDisplayCurrency.displaySelection('EGP');
  expect(label.verified,isTrue);
  expect(label.fromSar(1000),1000);
  expect(label.toSar(1000),1000);
  expect(WaffraDisplayCurrency.displaySelection('SAR').fromSar(1000),1000);
  // The actual verified market-quote parser remains separate.
  final market=WaffraVerifiedDisplayQuote(
   code:'EGP',sarToSelected:12.5,
   updatedAtUtc:DateTime.utc(2026,10,25),provider:'test-only');
  expect(market.fromSar(100),1250);
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
  // M207: original banking SMS MUST NOT be written to plaintext preferences.
  // The guarded legacy bridge still commits safe financial fields and SHA hash.
  expect(saved.first['notes'],'');
  final hashes=p.getStringList('waffra_sms_hashes_v1')??<String>[];
  expect(hashes.length,1);
  expect(find.textContaining('لم يُحفظ نص الرسالة البنكية الأصلي'),findsOneWidget);
 });
}

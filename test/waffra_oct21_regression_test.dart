import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 late String app;
 setUpAll(() => app = File('lib/main.dart').readAsStringSync());

 test('Income and expense PDF rows reuse exact transaction color constants', () {
  expect(waffraIncomeBackground.toARGB32(), 0xFFB2D5C2);
  expect(waffraExpenseBackground.toARGB32(), 0xFFFCECE8);
  expect(app, contains('PdfColor.fromInt(e.income?waffraIncomeBackground.toARGB32():waffraExpenseBackground.toARGB32())'));
  expect(app, contains("pdfCell('\u0024{row.key+1}',center:true)"));
  expect(app, contains("'رقم المعاملة'"));
  expect(app, contains("'No.'"));
 });

 test('Receipt corner reports number of attachments and hides on empty', () {
  expect(app, contains("if(attachmentCount>0)PositionedDirectional"));
  expect(app, contains("'عدد المرفقات \u0024attachmentCount'"));
  expect(app, contains("onTap:()=>showReceipt(e.receiptPath!)"));
  expect(app, isNot(contains("const Icon(Icons.attach_file,size:17,color:emerald)")));
 });

 test('Sensitive financial actions always require OS biometric authentication', () {
  final auth = File('lib/waffra_biometrics.dart').readAsStringSync();
  expect(auth, contains('biometricOnly: true'));
  expect(app, contains("_authorizeSensitiveAction('backing up or restoring data')"));
  expect(app, contains("_authorizeSensitiveAction('restoring data')"));
  expect(app, contains("_authorizeSensitiveAction('deleting financial data')"));
  expect(app, contains('WaffraBiometrics.isAvailable()'));
 });

 test('Android recent-app protection is independently adjustable', () {
  final native = File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(native, contains('override fun onPause()'));
  expect(native, contains('if (protectRecents) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)'));
  expect(native, contains('applyScreenshotSetting(screenshotsAllowed)'));
  expect(app, contains("'waffra_protect_recents_v1'"));
 });

 test('Account keeps one section expanded, searchable, with device appearance', () {
  expect(app, contains('_accountOpenSection=opened?null:heading'));
  expect(app, contains('AnimatedSize(duration:waffraMotion(220)'));
  expect(app, contains("Key('waffra-account-settings-search')"));
  expect(app, contains("value:widget.appearance"));
  expect(app, contains("value:'system'"));
  expect(app, contains("ThemeMode.system"));
  expect(app, contains("'waffra_appearance_mode_v1'"));
 });

 test('Tour explains six core sections and supports replay', () {
  expect(app, contains('static const tourTabs=<int>[0,0,0,1,2,3]'));
  expect(app, contains('List<GlobalKey>.generate(7'));
  expect(app, contains('tourStep==tourTabs.length-1'));
  expect(app, contains('void beginTour()'));
  expect(app, contains('void previousTour()'));
 });

 test('Undo actions retain five-second safe recovery for edit and delete', () {
  expect(RegExp(r'duration:const Duration\(seconds:5\)').allMatches(app).length, greaterThanOrEqualTo(2));
  expect(app, contains("actionLabel:waffraIsEnglish?'Undo':'تراجع'"));
  expect(app, contains('entries[index]=initial'));
  expect(app, contains('entries.insert(0,e)'));
 });

 testWidgets('Recovery actions use outlined Material controls', (tester) async {
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>
   waffraDeletedItemCard(context:ctx,icon:Icons.archive_outlined,iconColor:Colors.green,
    title:'هدف',subtitle:'متبقي 30 يوم',onRestore:(){},onDeleteForever:(){})))));
  expect(find.byType(OutlinedButton),findsNWidgets(2));
  expect(find.byIcon(Icons.restore_rounded),findsOneWidget);
  expect(find.byIcon(Icons.delete_forever_outlined),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}

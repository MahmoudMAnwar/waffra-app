import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
 setUp(() => waffraLanguage.value='ar');
 tearDown(() => waffraLanguage.value='ar');

 test('Every Dart screen uses the single footer notice presenter', () {
  final dartFiles=Directory('lib').listSync(recursive:true)
   .whereType<File>().where((f)=>f.path.endsWith('.dart')).toList();
  expect(dartFiles,isNotEmpty);
  var snackbarPresenters=0;
  for(final file in dartFiles){
   final source=file.readAsStringSync();
   snackbarPresenters+=RegExp(r'\.showSnackBar\s*\(').allMatches(source).length;
   expect(RegExp(r'\.showMaterialBanner\s*\(').hasMatch(source),isFalse,
    reason:'Header banners are forbidden in ${file.path}');
   expect(RegExp(r'\bMaterialBanner\s*\(').hasMatch(source),isFalse,
    reason:'Unexpected banner in ${file.path}');
   if(!file.path.endsWith('main.dart')){
    expect(RegExp(r'\bSnackBar\s*\(').hasMatch(source),isFalse,
     reason:'Route messages through the common footer notice: ${file.path}');
   }
  }
  expect(snackbarPresenters,1,
   reason:'Only the centralized notice presenter may call showSnackBar');
  final mainSource=File('lib/main.dart').readAsStringSync();
  expect(RegExp(r'\bSnackBar\s*\(').allMatches(mainSource).length,1);
  expect(mainSource,contains('void snackSuccess('));
  expect(mainSource,contains('InputDecoration'));
 });

 testWidgets('Arabic error is red and pinned directly above footer', (tester) async {
  const message='لا يمكن تصدير التقرير. يجب إضافة عملية دخل أو مصروف أولاً.';
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   appBar:AppBar(title:const Text('وفرة')),
   bottomNavigationBar:const SizedBox(
    key:Key('waffra-footer'),height:78,
    child:ColoredBox(color:Color(0xFF073F31))),
   body:Builder(builder:(ctx)=>TextButton(
    onPressed:()=>snack(ctx,message),
    child:const Text('Show error'))),
  )));
  await tester.tap(find.text('Show error'));
  await tester.pump(const Duration(milliseconds:350));
  final toast=tester.widget<SnackBar>(find.byType(SnackBar));
  expect(toast.behavior,SnackBarBehavior.floating);
  expect(toast.backgroundColor,const Color(0xFFFFE1E2));
  expect(find.byWidgetPredicate((w)=>w is WaffraText&&w.data==message),findsOneWidget);
  expect(find.byType(MaterialBanner),findsNothing);
  final toastBottom=tester.getBottomLeft(find.byType(SnackBar)).dy;
  final footerTop=tester.getTopLeft(find.byKey(const Key('waffra-footer'))).dy;
  expect(toastBottom,lessThanOrEqualTo(footerTop+1),
   reason:'Error toast must appear immediately above footer navigation');
 });

 testWidgets('Dark mode error stays red and supports dismiss', (tester) async {
  await tester.pumpWidget(MaterialApp(
   theme:ThemeData.dark(),
   home:Scaffold(body:Builder(builder:(ctx)=>TextButton(
    onPressed:()=>snack(ctx,'تعذر إتمام العملية'),
    child:const Text('Open error')))),
  ));
  await tester.tap(find.text('Open error'));
  await tester.pump(const Duration(milliseconds:350));
  expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
   const Color(0xFF4A2429));
  expect(find.byWidgetPredicate((w)=>w is WaffraText&&w.data=='تعذر إتمام العملية'),findsOneWidget);
  // Trigger the actual close-button callback directly: Tooltip wrappers do
  // not offer a stable hit-test target in every Flutter test viewport.
  final closeButton=tester.widget<IconButton>(
   find.widgetWithIcon(IconButton,Icons.close_rounded));
  closeButton.onPressed!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds:450));
  expect(find.byType(SnackBar),findsNothing);
 });

 testWidgets('Success notice is green but keeps same footer position', (tester) async {
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   bottomNavigationBar:const SizedBox(
    key:Key('waffra-footer'),height:78,
    child:ColoredBox(color:Color(0xFF073F31))),
   body:Builder(builder:(ctx)=>TextButton(
    onPressed:()=>snackSuccess(ctx,'تم الحفظ بنجاح'),
    child:const Text('Show success'))),
  )));
  await tester.tap(find.text('Show success'));
  await tester.pump(const Duration(milliseconds:350));
  final notice=tester.widget<SnackBar>(find.byType(SnackBar));
  expect(notice.backgroundColor,const Color(0xFFE6F5EB));
  expect(find.byWidgetPredicate((w)=>w is WaffraText&&w.data=='تم الحفظ بنجاح'),findsOneWidget);
  expect(tester.getBottomLeft(find.byType(SnackBar)).dy,
   lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('waffra-footer'))).dy+1));
 });
}

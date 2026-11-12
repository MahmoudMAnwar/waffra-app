import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

/// M671: no tour remains on first launch or in Settings, and any genuine
/// tap hides the notice without hijacking the original target/Undo.
void main() {
 test('M671 permanently removes source tour and settings replay',(){
  const root='lib/main.dart';
  final source=File(root).readAsStringSync();
  expect(File('lib/waffra_tour_plan.dart').existsSync(),isFalse);
  for(final old in <String>[
   'tourActive','tourOverlay','WaffraTourPlan','_tourGlow',
   '_tourKeys','waffra_in_app_tour_seen_v2',
   'Replay app tour','إعادة الجولة التعريفية','beginTour()',
  ]){
   expect(source,isNot(contains(old)),reason:old);
  }
  expect(source,contains("waffraIsEnglish?'About Waffra':'عن وفرة'"));
  expect(source,contains("WaffraFooterNavigation.itemCount-1"));
  expect(source,contains("waffraAnimationLevel.value=next;"));
 });

 testWidgets('M671 fallback Snackbar disappears on next unrelated tap without blocking it',
  (tester)async{
  var actualTaps=0;
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,child)=>WaffraNoticeTapDismissArea(child:child!),
   home:Scaffold(body:Builder(builder:(ctx)=>Column(children:[
    TextButton(onPressed:()=>snack(ctx,'Long message with no close',
     kind:WaffraSnackKind.info,requireDismissal:true),
     child:const Text('Show fallback')),
    TextButton(onPressed:()=>actualTaps++,child:const Text('Real action')),
   ]))),
  ));
  await tester.tap(find.text('Show fallback'));
  await tester.pump(const Duration(milliseconds:350));
  expect(find.byType(SnackBar),findsOneWidget);
  expect(find.byKey(const Key('waffra-snackbar-close')),findsNothing);
  await tester.tap(find.text('Real action'));
  await tester.pump();
  expect(actualTaps,1,reason:'Tap must still activate its original target');
  expect(find.byType(SnackBar),findsNothing);
  expect(tester.takeException(),isNull);
 });

 testWidgets('M671 footer notice closes instantly on a normal content tap',
  (tester)async{
  var selected=0;
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,child)=>WaffraNoticeTapDismissArea(child:child!),
   home:Scaffold(
    body:Builder(builder:(ctx)=>Column(children:[
     TextButton(onPressed:()=>snack(ctx,
      'لا توجد رسائل جديدة للمراجعة.',
      preferFooter:true,isError:false,requireDismissal:true),
      child:const Text('Show footer')),
     TextButton(onPressed:()=>selected++,child:const Text('Change filter')),
    ])),
    bottomNavigationBar:const Column(mainAxisSize:MainAxisSize.min,children:[
     WaffraFooterNoticeHost(),SizedBox(height:76),
    ]),
   ),
  ));
  await tester.tap(find.text('Show footer'));
  await tester.pumpAndSettle();
  expect(find.byType(WaffraNoticeContent),findsOneWidget);
  await tester.tap(find.text('Change filter'));
  await tester.pump();
  expect(selected,1);
  expect(find.byType(WaffraNoticeContent),findsNothing);
  expect(tester.takeException(),isNull);
 });

 testWidgets('M671 Undo uses the same tap exactly once, then dismisses',
  (tester)async{
  var undo=0;
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,child)=>WaffraNoticeTapDismissArea(child:child!),
   home:Scaffold(
    body:Builder(builder:(ctx)=>TextButton(
     onPressed:()=>snack(ctx,'Edited successfully',
      preferFooter:true,kind:WaffraSnackKind.success,
      requireDismissal:true,actionLabel:'Undo',
      onAction:()=>undo++),
     child:const Text('Show undo'))),
    bottomNavigationBar:const WaffraFooterNoticeHost(),
   ),
  ));
  await tester.tap(find.text('Show undo'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-snackbar-action')),findsOneWidget);
  await tester.tap(find.byKey(const Key('waffra-snackbar-action')));
  await tester.pumpAndSettle();
  expect(undo,1);
  expect(find.byType(WaffraNoticeContent),findsNothing);
  expect(tester.takeException(),isNull);
 });

 testWidgets('M671 tap inside a pushed dialog dismisses footer notice and runs button',
  (tester)async{
  var dialogTaps=0;
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,child)=>WaffraNoticeTapDismissArea(child:child!),
   home:Scaffold(
    body:Builder(builder:(ctx)=>Column(children:[
     TextButton(onPressed:()=>snack(ctx,'Temporary notice',
      preferFooter:true,isError:false,requireDismissal:true),
      child:const Text('Show notice')),
     TextButton(onPressed:()=>showDialog<void>(context:ctx,
      builder:(dialog)=>AlertDialog(
       content:TextButton(onPressed:()=>dialogTaps++,
        child:const Text('Dialog action')))),
      child:const Text('Show dialog')),
    ])),
    // Match the actual Home: footer notice is never the whole navigation bar.
    // Fixed navigation area must remain during a notice-dismiss/modal push.
    bottomNavigationBar:const Column(mainAxisSize:MainAxisSize.min,children:[
     WaffraFooterNoticeHost(),SizedBox(height:76),
    ]),
   ),
  ));
  await tester.tap(find.text('Show notice'));
  await tester.pumpAndSettle();
  expect(find.byType(WaffraNoticeContent),findsOneWidget);
  await tester.tap(find.text('Show dialog'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog),findsOneWidget,
   reason:'The actual tap must open a modal while dismissing the notice.');
  // Opening a dialog is itself a tap, and must already clear the old notice.
  expect(find.byType(WaffraNoticeContent),findsNothing);
  await tester.tap(find.text('Dialog action'));
  await tester.pump();
  expect(dialogTaps,1);
  expect(tester.takeException(),isNull);
 });

 testWidgets('M671 scrolling is not mistaken for a tap',
  (tester)async{
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,child)=>WaffraNoticeTapDismissArea(child:child!),
   home:Scaffold(
    body:Builder(builder:(ctx)=>ListView(children:[
     TextButton(onPressed:()=>snack(ctx,'Still visible',
      preferFooter:true,isError:false,requireDismissal:true),
      child:const Text('Show notice')),
     for(var i=0;i<30;i++)SizedBox(height:50,child:Text('Entry $i')),
    ])),
    bottomNavigationBar:const WaffraFooterNoticeHost(),
   ),
  ));
  await tester.tap(find.text('Show notice'));
  await tester.pumpAndSettle();
  expect(find.byType(WaffraNoticeContent),findsOneWidget);
  await tester.drag(find.byType(ListView),const Offset(0,-120));
  await tester.pumpAndSettle();
  expect(find.byType(WaffraNoticeContent),findsOneWidget);
 });
}

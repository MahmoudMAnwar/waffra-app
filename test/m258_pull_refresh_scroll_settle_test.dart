import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_pull_refresh_scroll_settle.dart';

void main(){
 testWidgets('pull refresh settles the original list at its top', (tester)async {
  final controller=ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:ListView(controller:controller,
    physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
    children:const [SizedBox(height:2200)]))));
  controller.jumpTo(160);
  expect(controller.offset,greaterThan(0));
  var loaded=false;
  final done=waffraRefreshAndRestoreScroll(
   refresh:()async{loaded=true;},
   controller:controller,
   isStillVisible:()=>true);
  await tester.pump();
  await done;
  expect(loaded,isTrue);
  expect(controller.offset,controller.position.minScrollExtent);
 });

 testWidgets('does not alter scroll for a tab the user left', (tester)async {
  final controller=ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:ListView(controller:controller,children:const [SizedBox(height:2200)]))));
  controller.jumpTo(140);
  final before=controller.offset;
  var stillVisible=true;
  final done=waffraRefreshAndRestoreScroll(
   refresh:()async{stillVisible=false;},
   controller:controller,
   isStillVisible:()=>stillVisible);
  await done;
  expect(controller.offset,before);
 });

 testWidgets('never masks an authoritative refresh failure', (tester)async {
  final controller=ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:ListView(controller:controller,children:const [SizedBox(height:2200)]))));
  controller.jumpTo(120);
  await expectLater(
   waffraRefreshAndRestoreScroll(
    refresh:()async{throw StateError('finance verification failed');},
    controller:controller,isStillVisible:()=>true),
   throwsStateError);
  expect(controller.offset,120);
 });

 testWidgets('actual pull gesture clears blank top space on short finance list', (tester)async {
  final controller=ScrollController();
  addTearDown(controller.dispose);
  var refreshes=0;
  const hero=Key('finance-hero');
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:RefreshIndicator(
    onRefresh:()=>waffraRefreshAndRestoreScroll(
     refresh:()async{refreshes++;},
     controller:controller,
     isStillVisible:()=>true),
    child:ListView(controller:controller,
     physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
     children:const [
      SizedBox(key:hero,height:70),
      SizedBox(height:140),
     ]),
   ))));
  final originalTop=tester.getTopLeft(find.byKey(hero)).dy;
  await tester.drag(find.byType(ListView),const Offset(0,470));
  await tester.pumpAndSettle();
  expect(refreshes,1);
  expect(controller.offset,controller.position.minScrollExtent);
  expect(tester.getTopLeft(find.byKey(hero)).dy,closeTo(originalTop,1.0));
 });
}

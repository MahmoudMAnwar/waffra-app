import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('English plus physically RIGHT, Arabic plus physically LEFT'
      ' across Home, Categories, Goals and Recurring', () {
    for (final tab in <int>[0, 1, 2, 3]) {
      final english = WaffraDirectionalFabLocation.horizontalOffset(
        english: true, scaffoldWidth: 390, fabWidth: 58,
        leftInset: 0, rightInset: 0,
      );
      final arabic = WaffraDirectionalFabLocation.horizontalOffset(
        english: false, scaffoldWidth: 390, fabWidth: 58,
        leftInset: 0, rightInset: 0,
      );
      expect(english, 316, reason: 'English tab $tab must anchor right');
      expect(arabic, 16, reason: 'Arabic tab $tab must anchor left');
    }
  });

  test('plus respects both physical system insets on narrow screens', () {
    expect(WaffraDirectionalFabLocation.horizontalOffset(
      english: true, scaffoldWidth: 320, fabWidth: 58,
      leftInset: 2, rightInset: 22,
    ), 224);
    expect(WaffraDirectionalFabLocation.horizontalOffset(
      english: false, scaffoldWidth: 320, fabWidth: 58,
      leftInset: 25, rightInset: 0,
    ), 41);
  });

  testWidgets('receipt count is INSIDE a clipped corner marker in both languages',
      (tester) async {
    for (final english in <bool>[true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(body: WaffraReceiptCornerBadge(
            count: 6, english: english,
          )),
        ),
      ));
      expect(find.text('6'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
      final clip = tester.widget<ClipPath>(
        find.ancestor(
          of: find.text('6'),
          matching: find.byType(ClipPath),
        ).first,
      );
      expect((clip.clipper as WaffraReceiptCornerClipper).english, english);
    }
  });

  test('all four tab plus actions use locale switch, with no fixed-left anchor',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains(
      'floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)',
    ));
    expect(source, contains(
      'floatingActionButtonAnimator:const WaffraStationaryFabAnimator()',
    ));
    expect(source, contains(
      'floatingActionButton:!ready||tab==4?null:SizedBox(',
    ));
    expect(source, contains('width:58,height:58'));
    expect(source, contains('WaffraFabMenuAnchor('));
    expect(source, contains('expanded:addFabExpanded&&!goalsOpened'));
    expect(source, isNot(contains(
      'floatingActionButton:!ready||tab==4?null:Directionality(',
    )));
    expect(source, contains('if(goalsOpened||tab==2){unawaited(_launchAddAction(()=>goalDialog()));return;}'));
    expect(source, contains('if(tab==3){unawaited(_launchAddAction(()=>recurringDialog()));return;}'));
    expect(source, isNot(contains('WaffraPhysicalLeftFab')));
  });

  test('attachment marker is anchored in a card corner and contains its count',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(attachmentCount>0)PositionedDirectional(top:0,end:0'));
    expect(source, contains(
      'WaffraReceiptCornerBadge(count:attachmentCount,english:waffraIsEnglish)',
    ));
    expect(source, contains("onTap:()=>showReceipt(e.receiptPath!)"));
    expect(source, contains('child:WaffraReceiptCornerBadge'));
  });
  testWidgets('expanded menu is above the physical plus on the same side in both languages', (tester) async {
    Widget harness(bool english) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,height: 500,
            child: Stack(children:[
              WaffraFabMenuAnchor(
                english:english,expanded:true,
                menu:Container(key:const Key('menu-anchor-probe'),
                  width:220,height:96,color:Colors.green),
              ),
            ]),
          ),
        ),
      ),
    );
    for (final english in <bool>[true,false]) {
      await tester.pumpWidget(harness(english));
      await tester.pumpAndSettle();
      final rect=tester.getRect(find.byKey(const Key('menu-anchor-probe')));
      expect(rect.width,220);
      expect(rect.height,96);
      expect(rect.left,english?154:16,
        reason:'Menu must be anchored above English-right/Arabic-left FAB');
      expect(rect.right,english?374:236,
        reason:'Menu cannot drift to the opposite physical edge');
      expect(rect.bottom,414,
        reason:'Menu ends 12px above the stable 58px plus');
      expect(tester.takeException(),isNull);
    }
  });

  test('FAB location never animates horizontally on tab or language switch', () {
    const animator=WaffraStationaryFabAnimator();
    const old=Offset(16,500);
    const next=Offset(316,500);
    for (final progress in <double>[0,0.25,0.5,0.75,1]) {
      expect(animator.getOffset(begin:old,end:next,progress:progress),next);
    }
    const incoming=AlwaysStoppedAnimation<double>(0.3);
    expect(animator.getScaleAnimation(parent:incoming).value,1);
    expect(animator.getRotationAnimation(parent:incoming).value,1);
  });

}

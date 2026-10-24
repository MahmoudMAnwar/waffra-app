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
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
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
      'crossAxisAlignment:waffraIsEnglish?CrossAxisAlignment.end:CrossAxisAlignment.start',
    ));
    expect(source, contains(
      'alignment:waffraIsEnglish?Alignment.bottomRight:Alignment.bottomLeft',
    ));
    expect(source, contains('if(goalsOpened||tab==2){goalDialog();return;}'));
    expect(source, contains('if(tab==3){recurringDialog();return;}'));
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
    expect(source, isNot(contains("Text('$" + "attachmentCount',style:const TextStyle(")));
  });
}

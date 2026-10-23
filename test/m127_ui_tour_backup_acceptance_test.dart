import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  test('four finance destinations share one bottom-left circular action', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('floatingActionButtonLocation:const WaffraPhysicalLeftFab()'));
    expect(source,contains('floatingActionButton:!ready||tab==4?null:Directionality('));
    expect(source,contains('if(goalsOpened||tab==2){goalDialog();return;}'));
    expect(source,contains('if(tab==3){recurringDialog();return;}'));
    expect(source,contains('child:SizedBox(key:_tourKeys[1],width:58,height:58'));
    expect(source,contains('onTap:()=>setState(()=>addFabExpanded=!addFabExpanded)'),
        isFalse);
    final goalsStart=source.indexOf('Widget goalsPage()');
    final recurringStart=source.indexOf('Widget recurringPage()');
    expect(goalsStart,greaterThanOrEqualTo(0));
    expect(recurringStart,greaterThan(goalsStart));
    final goalSection=source.substring(goalsStart,recurringStart);
    expect(goalSection.contains('FilledButton.icon(onPressed:goalDialog'),false);
    final recurringEnd=source.indexOf('Future<void> showWaffraFinancialCalendar()',recurringStart);
    expect(recurringEnd,greaterThan(recurringStart));
    final recurringSection=source.substring(recurringStart,recurringEnd);
    expect(recurringSection.contains('FilledButton.icon(onPressed:recurringDialog'),false);
    expect(recurringSection.contains('OutlinedButton.icon(onPressed:recurringDialog'),false);
  });

  test('tour intro no longer cuts through the top header', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('tourStep==0?Rect.fromLTWH(-40,-40,1,1)'));
    expect(source,contains('final suggestedTop=tourStep==0?'));
    expect(source,contains('final suggestedLeft=tourStep==0?'));
    expect(source,contains('if(tourActive&&tourTargetReady)Positioned.fill(child:tourOverlay())'));
  });

  test('backup password field is capped at eight except legacy restore', () {
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('LengthLimitingTextInputFormatter(8)'));
    expect(source,contains("RegExp(r'[A-Za-z0-9]')"));
    expect(source,contains('if(!WaffraSecureBackup.isValidNewPassword(secret.text))'));
    expect(source,contains('legacyRestorePassword?const <TextInputFormatter>[]'));
    expect(source,contains('Restore an older backup password'));
  });

  for (final direction in [TextDirection.rtl,TextDirection.ltr]) {
    testWidgets('physical left + stays left in $direction',(tester) async {
      await tester.binding.setSurfaceSize(const Size(390,760));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home:Directionality(
          textDirection:direction,
          child:Scaffold(
            bottomNavigationBar:const SizedBox(height:85),
            floatingActionButtonLocation:const WaffraPhysicalLeftFab(),
            floatingActionButton:FloatingActionButton(
              key:const Key('waffra-m127-plus'),
              onPressed:(){},
              child:const Icon(Icons.add),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final rect=tester.getRect(find.byKey(const Key('waffra-m127-plus')));
      expect(rect.left,greaterThanOrEqualTo(12));
      expect(rect.left,lessThanOrEqualTo(40));
      expect(rect.right,lessThan(120));
      expect(tester.takeException(),isNull);
    });
  }
}

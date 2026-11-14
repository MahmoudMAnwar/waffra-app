import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

/// Owner-approved M644: normal page margins without a FAB; fixed bottom edge.
void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  for (final english in [false, true]) {
    testWidgets('M644 no FAB fills page width and wraps upward', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      waffraLanguage.value = english ? 'en' : 'ar';
      final notice = ValueNotifier<WaffraNoticeData?>(
        const WaffraNoticeData(
          text: 'Saved',
          kind: WaffraSnackKind.success,
          duration: Duration(seconds: 5),
          requireDismissal: true,
        ),
      );
      addTearDown(notice.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(body: Stack(children: [
            PositionedDirectional(
              start: 12, end: 12, bottom: 90,
              child: WaffraFooterNoticeHost(
                expandToAvailableWidth: true,
                listenable: notice,
                onDismiss: () => notice.value = null,
              ),
            ),
          ])),
        ),
      ));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(WaffraNoticeEdgeBody));
      expect((before.left - 12).abs(), lessThan(1));
      expect((before.right - 348).abs(), lessThan(1));
      notice.value = const WaffraNoticeData(
        text: 'This is a deliberately long message that needs to wrap to '
              'several lines without changing the bottom edge of the notice '
              'or reserving any space for an absent plus button.',
        kind: WaffraSnackKind.error,
        duration: Duration(seconds: 5),
        requireDismissal: true,
      );
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(WaffraNoticeEdgeBody));
      expect((after.left - before.left).abs(), lessThan(1));
      expect((after.right - before.right).abs(), lessThan(1));
      expect((after.bottom - before.bottom).abs(), lessThan(1));
      expect(after.height, greaterThan(before.height));
      expect(tester.takeException(), isNull);
    });
  }

  test('M644 all no-FAB routes including opened account show wide notice', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('if(!accountOpened&&ready&&tab!=2)'));
    expect(source, contains('floatingActionButton:!ready||accountOpened||tab==2?null:'));
    expect(source, contains('if(accountOpened||tab==2||!ready)'));
    expect(source, contains('bottom:accountOpened?12:90,'));
    expect(source, contains(
      'WaffraFooterNoticeHost(expandToAvailableWidth:true)'));
    expect(source, contains(
      'floatingActionButtonLocation:WaffraDirectionalFabLocation('));
    expect(source, contains(
      'floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
  });
}

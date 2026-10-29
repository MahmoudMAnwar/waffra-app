import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_action_layout.dart';
import 'package:waffra/waffra_practical_tools_page.dart';

/// Regression for M283's gap: changing padding does not fix buttons stretched
/// by an ancestor Column or SizedBox(width: double.infinity).
void main() {
  test('Shared actions keep 48dp taps and 20dp total horizontal inset', () {
    expect(WaffraActionLayout.minimumSize.height, 48);
    expect(WaffraActionLayout.contentPadding.horizontal, 20);
    expect(WaffraActionLayout.contentPadding.vertical, 16);
  });

  for (final english in <bool>[false, true]) {
    for (final width in <double>[320, 390]) {
      testWidgets(
        'M285 receipt assistant actions are content-width, not screen-width '
        '${english ? 'EN' : 'AR'} $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final theme = ThemeData(
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: WaffraActionLayout.minimumSize,
                padding: WaffraActionLayout.contentPadding)),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: WaffraActionLayout.minimumSize,
                padding: WaffraActionLayout.contentPadding)),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: WaffraActionLayout.minimumSize,
                padding: WaffraActionLayout.contentPadding)),
          );

          final heading = english
              ? 'Receipt OCR scanner'
              : 'قارئ الفواتير OCR';
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Directionality(
              textDirection: english ? TextDirection.ltr : TextDirection.rtl,
              child: WaffraPracticalToolsPage(
                english: english, entries: const []),
            ),
          ));
          await tester.pumpAndSettle();
          final headingFinder = find.text(heading);
          await tester.scrollUntilVisible(headingFinder, 160,
            scrollable: find.byType(Scrollable).first);
          await tester.tap(headingFinder);
          await tester.pumpAndSettle();

          final notice = english
              ? 'Choose a receipt image to scan automatically.'
              : 'اختر صورة فاتورة ليقرأها وفرة تلقائيًا.';
          expect(find.textContaining(notice), findsOneWidget);

          final dateButton = find.widgetWithText(
            TextButton, english ? 'Receipt date' : 'تاريخ الفاتورة');
          final validateButton = find.widgetWithText(
            FilledButton,
            english ? 'Validate receipt draft' : 'التحقق من بيانات الفاتورة');
          await tester.scrollUntilVisible(dateButton, 160,
            scrollable: find.byType(Scrollable).first);
          expect(dateButton, findsOneWidget);
          await tester.scrollUntilVisible(validateButton, 160,
            scrollable: find.byType(Scrollable).first);
          expect(validateButton, findsOneWidget);

          for (final button in <Finder>[dateButton, validateButton]) {
            final bounds = tester.getSize(button);
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(bounds.width, lessThan(width - 36),
              reason: 'A secondary action border must hug its content.');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

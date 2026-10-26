import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_action_layout.dart';

void main() {
  testWidgets('bordered text and icon have breathing room in Arabic RTL',
      (tester) async {
    await _verifyActionLayout(tester, TextDirection.rtl, Brightness.light);
  });

  testWidgets('bordered text and icon have breathing room in English LTR',
      (tester) async {
    await _verifyActionLayout(tester, TextDirection.ltr, Brightness.light);
  });

  testWidgets('dark mode keeps icon vertically centered with wrapped label',
      (tester) async {
    await _verifyActionLayout(tester, TextDirection.rtl, Brightness.dark);
  });
}

Future<void> _verifyActionLayout(
  WidgetTester tester,
  TextDirection direction,
  Brightness brightness,
) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: WaffraActionLayout.minimumSize,
          padding: WaffraActionLayout.contentPadding,
          alignment: Alignment.center,
        ),
      ),
    ),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 265,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.currency_exchange,
                  key: Key('action-icon'), size: 22),
              label: const Text(
                'حوّل قيمة الذهب إلى ريال أو جنيه مصري',
                key: Key('action-label'),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ),
  ));

  final button = tester.getRect(find.byType(OutlinedButton));
  final label = tester.getRect(find.byKey(const Key('action-label')));
  final icon = tester.getRect(find.byKey(const Key('action-icon')));
  expect(button.height, greaterThanOrEqualTo(52));
  expect(label.top - button.top, greaterThanOrEqualTo(10));
  expect(button.bottom - label.bottom, greaterThanOrEqualTo(10));
  expect(label.left - button.left, greaterThanOrEqualTo(12));
  expect(button.right - label.right, greaterThanOrEqualTo(12));
  expect((label.center.dy - icon.center.dy).abs(), lessThanOrEqualTo(8));
  if (direction == TextDirection.rtl) {
    expect(icon.center.dx, greaterThan(label.center.dx));
  } else {
    expect(icon.center.dx, lessThan(label.center.dx));
  }
  expect(tester.takeException(), isNull);
}

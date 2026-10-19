import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';

void main() {
  for (final viewport in <Size>[
    const Size(360, 700),
    const Size(393, 850),
    const Size(430, 932),
  ]) {
    testWidgets('Onboarding text and CTA remain visible at ${viewport.width}x${viewport.height}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var finished = false;
      await tester.pumpWidget(MaterialApp(
        home: WaffraOnboarding(onFinish: () => finished = true),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final cta = find.byType(FilledButton).first;
      final skip = find.byType(TextButton).first;
      final ctaRect = tester.getRect(cta);
      final skipRect = tester.getRect(skip);
      expect(ctaRect.left, greaterThanOrEqualTo(0));
      expect(ctaRect.right, lessThanOrEqualTo(viewport.width));
      expect(ctaRect.bottom, lessThanOrEqualTo(viewport.height));
      expect(skipRect.top, greaterThanOrEqualTo(0));
      expect(skipRect.bottom, lessThanOrEqualTo(viewport.height));

      for (var page = 0; page < 4; page++) {
        await tester.tap(find.byType(FilledButton).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(finished, isTrue);
    });
  }
}

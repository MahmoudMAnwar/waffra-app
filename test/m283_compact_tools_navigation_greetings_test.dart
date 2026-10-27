import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_action_layout.dart';
import 'package:waffra/waffra_back_navigation.dart';
import 'package:waffra/waffra_saudi_greetings.dart';
import 'package:waffra/waffra_smart_features.dart';

void main() {
  group('M283 Saudi cold-start greeting rotation', () {
    test('five consecutive launches never repeat, even across restart cycle', () {
      var previous = -1;
      final seen = <String>{};
      for (var i = 0; i < 5; i++) {
        previous = WaffraSaudiGreetings.nextIndex(previous);
        final text = WaffraSaudiGreetings.compose(
          name: 'محمد', gender: 'ذكر', english: false,
          greetingIndex: previous);
        expect(text, contains('محمد'));
        expect(text, isNot(contains('هلا وغلا')));
        expect(seen.add(text), isTrue);
      }
      expect(WaffraSaudiGreetings.nextIndex(previous), 0);
    });
    test('female/masculine honorifics differ; empty gender is neutral', () {
      for (var i = 0; i < 5; i++) {
        final female = WaffraSaudiGreetings.compose(
          name: 'نورة', gender: 'أنثى', english: false, greetingIndex: i);
        final male = WaffraSaudiGreetings.compose(
          name: 'سعود', gender: 'ذكر', english: false, greetingIndex: i);
        final unknown = WaffraSaudiGreetings.compose(
          name: '', gender: '', english: false, greetingIndex: i);
        expect(female, contains('نورة'));
        expect(male, contains('سعود'));
        expect(female, isNot(contains('يا هلا وغلا')));
        expect(male, isNot(contains('يا هلا وغلا')));
        expect(unknown, isNot(contains('يا ' + 'يا ')));
      }
    });
    test('English persists language, does not display Arabic, anonymous safe', () {
      final english = WaffraSaudiGreetings.compose(
        name: 'Sara', gender: 'female', english: true, greetingIndex: 2);
      expect(english, contains('Sara'));
      expect(english, isNot(contains('يا ')));
      expect(WaffraSaudiGreetings.compose(
        name: 'يا غالي', gender: '', english: false, greetingIndex: 0),
        isNot(contains('يا غالي')));
    });
  });

  group('M283 account/home back then two-press exit', () {
    test('only a second press within 2500ms requests app exit', () {
      final gate = WaffraDoubleBackExit();
      final start = DateTime(2026, 10, 27, 17);
      expect(gate.isExitPress(start), isFalse);
      expect(gate.isExitPress(start.add(const Duration(seconds: 2))), isTrue);
      expect(gate.isExitPress(start.add(const Duration(seconds: 3))), isFalse);
      expect(gate.isExitPress(start.add(const Duration(seconds: 6))), isFalse);
    });
    test('back navigation home resets the armed exit and expiry', () {
      final gate = WaffraDoubleBackExit();
      final now = DateTime(2026, 10, 27, 17);
      expect(gate.isExitPress(now), isFalse);
      gate.reset();
      expect(gate.isExitPress(now.add(const Duration(milliseconds: 500))), isFalse);
      expect(gate.isExitPress(now.add(const Duration(milliseconds: 4000))), isFalse);
    });
  });

  test('M283 all shared button borders use compact padding and >=48dp targets', () {
    expect(WaffraActionLayout.minimumSize.height, greaterThanOrEqualTo(48));
    expect(WaffraActionLayout.contentPadding.horizontal, lessThanOrEqualTo(24));
    expect(WaffraActionLayout.contentPadding.vertical, lessThanOrEqualTo(20));
  });

  for (final english in <bool>[false, true]) {
    testWidgets('M283 accordion opens at top of visible tools viewport in ' +
        (english ? 'English' : 'Arabic'), (tester) async {
      tester.view.physicalSize = const Size(390, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: WaffraSmartFeaturesPage(
        english: english, entries: const [], goals: const [], recurring: const [],
      )));
      await tester.pumpAndSettle();
      final title = english ? 'Subscription detective' : 'صائد الاشتراكات';
      final feature = find.text(title).first;
      await tester.ensureVisible(feature);
      await tester.pumpAndSettle();
      await tester.tap(feature);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final box = find.byKey(const Key('waffra-m268-accordion-subscription'));
      final rect = tester.getRect(box);
      expect(rect.top, greaterThanOrEqualTo(40));
      expect(rect.top, lessThan(230),
          reason: 'Expanded tool heading must scroll near the top after opening');
      expect(find.byKey(const Key('waffra-m268-expanded-subscription')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      final forbidden = english ? 'Expand any tool here' : 'افتح أي أداة هنا';
      expect(find.textContaining(forbidden), findsNothing);
    });
  }

  testWidgets('M283 reduced-motion still scrolls and keeps tool accessible',
      (tester) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: WaffraSmartFeaturesPage(
        english: true, entries: const [], goals: const [], recurring: const [],
      ),
    )));
    await tester.pumpAndSettle();
    final feature = find.text('Subscription detective').first;
    await tester.ensureVisible(feature);
    await tester.tap(feature);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-m268-expanded-subscription')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

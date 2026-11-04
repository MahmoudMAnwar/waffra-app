import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smart_features.dart';
import 'package:waffra/waffra_tour_plan.dart';

void main() {
  test('M286 onboarding always visits the current five-tab footer, including tools', () {
    expect(WaffraTourPlan.tabs, <int>[0, 0, 0, 1, 2, 3, 4]);
    expect(WaffraTourPlan.targetKeys, <int>[-1, 0, 1, 2, 3, 6, 4]);
    for (final steps in <List<String>>[
      WaffraTourPlan.titlesAr,
      WaffraTourPlan.titlesEn,
      WaffraTourPlan.helpAr,
      WaffraTourPlan.helpEn,
    ]) {
      expect(steps.length, WaffraTourPlan.tabs.length);
      expect(steps.every((label) => label.trim().isNotEmpty), isTrue);
    }
    expect(WaffraTourPlan.titlesAr[4], contains('الأدوات'));
    expect(WaffraTourPlan.titlesEn[4], contains('tools'));
    expect(WaffraTourPlan.targetKeys.where((key) => key == -1).length, 1);
  });

  test('M286 replay leaves Account and tour overlay remains reachable', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains(
      'tourStep=0;tourActive=true;tourTargetReady=false;tab=0;accountOpened=false;'));
    expect(source, contains('tourHeadingKey:_tourKeys[3]'));
    expect(source, contains('tourTabs=WaffraTourPlan.tabs'));
    expect(source, contains('tourTargetKeys=WaffraTourPlan.targetKeys'));
    expect(source, contains('if(tourActive&&tourTargetReady)Positioned.fill'));
  });

  for (final english in <bool>[false, true]) {
    for (final width in <double>[320, 393, 600]) {
      testWidgets('M286 tools tour target mounted/visible, english=$english width=$width',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final anchor = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: english ? TextDirection.ltr : TextDirection.rtl,
            child: Scaffold(body: WaffraSmartFeaturesPage(
              embedded: true,
              english: english,
              tourHeadingKey: anchor,
              entries: const [],
              goals: const [],
              recurring: const [],
            )),
          ),
        ));
        await tester.pumpAndSettle();
        final target = find.byKey(anchor);
        expect(target, findsOneWidget);
        expect(anchor.currentContext, isNotNull);
        final bounds = tester.getRect(target);
        expect(bounds.width, greaterThan(120));
        expect(bounds.height, greaterThan(45));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(800));
        expect(find.text(english ? 'Waffra smart tools' : 'أدوات وفرة الذكية'),
            findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

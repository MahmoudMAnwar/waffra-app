import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_i18n.dart';

/// M277: independent, synthetic UX/accessibility acceptance on the real footer
/// and error host. No production storage, account, or finance data is touched.
/// Physical Android TalkBack and gesture smoothness remain separate checks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    waffraLanguage.value = 'ar';
  });
  tearDown(() {
    waffraLanguage.value = 'ar';
  });

  Widget footerHarness({
    required bool english,
    required double textScale,
    required bool reduceMotion,
    required ValueChanged<int> onSelected,
    required int selected,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        fontFamily: 'Tajawal',
      ),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: Directionality(
          textDirection: english ? TextDirection.ltr : TextDirection.rtl,
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: WaffraFooterNavigation(
              selectedIndex: selected,
              english: english,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  const labelsAr = <String>[
    'الرئيسية', 'الأقسام', 'الأدوات', 'الأهداف', 'المتكررة',
  ];
  const labelsEn = <String>[
    'Home', 'Categories', 'Smart tools', 'Goals', 'Recurring',
  ];

  for (final width in <double>[320, 393]) {
    for (final english in <bool>[false, true]) {
      testWidgets(
        'M277: screen-reader labels, 48dp touch targets and real taps '
        'at $width dp, english=$english, 200% text',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final handle = tester.ensureSemantics();
          var selected = 0;
          await tester.pumpWidget(
            StatefulBuilder(builder: (context, update) => footerHarness(
              english: english,
              textScale: 2,
              reduceMotion: true,
              selected: selected,
              onSelected: (next) => update(() => selected = next),
            )),
          );
          await tester.pumpAndSettle();

          final labels = english ? labelsEn : labelsAr;
          final first = tester.getRect(find.byKey(const Key('waffra-nav-0')));
          final second = tester.getRect(find.byKey(const Key('waffra-nav-1')));
          if (english) {
            expect(first.center.dx, lessThan(second.center.dx),
                reason: 'LTR must retain expected logical tab order');
          } else {
            expect(first.center.dx, greaterThan(second.center.dx),
                reason: 'RTL must mirror the footer order');
          }

          for (var index = 0; index < 5; index++) {
            final target = find.byKey(Key('waffra-nav-$index'));
            expect(target, findsOneWidget);
            final rect = tester.getRect(target);
            expect(rect.width, greaterThanOrEqualTo(48),
                reason: 'Footer tap target too narrow for accessibility');
            expect(rect.height, greaterThanOrEqualTo(48),
                reason: 'Footer tap target too short for accessibility');
            expect(rect.left, greaterThanOrEqualTo(-0.5));
            expect(rect.right, lessThanOrEqualTo(width + 0.5));

            final semantic = find.byWidgetPredicate((widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.label == labels[index]);
            expect(semantic, findsOneWidget,
                reason: 'A label must remain available to TalkBack even '
                    'when 200% visible text is ellipsized');
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(selected, index);
            expect(tester.widget<Semantics>(semantic).properties.selected, isTrue,
                reason: 'TalkBack must announce the newly selected tab');
            expect(tester.takeException(), isNull);
          }
          handle.dispose();
        },
      );
    }
  }

  testWidgets('M277: Reduce Motion removes tab animation durations '
      'but never disables navigation', (tester) async {
    final handle = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(StatefulBuilder(builder: (context, update) =>
        footerHarness(
          english: false,
          textScale: 1,
          reduceMotion: true,
          selected: selected,
          onSelected: (next) => update(() => selected = next),
        )));
    await tester.pump();
    final animated = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('waffra-modern-footer')),
          matching: find.byType(AnimatedContainer),
        )).toList();
    expect(animated, isNotEmpty);
    expect(animated.every((widget) => widget.duration == Duration.zero), isTrue,
        reason: 'OS Reduce Motion must disable decorative footer transitions');
    await tester.tap(find.byKey(const Key('waffra-nav-3')));
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('M277: footer text contrast across rendered dark-green gradient',
      (tester) async {
    await tester.pumpWidget(footerHarness(
      english: true,
      textScale: 1,
      reduceMotion: false,
      selected: 0,
      onSelected: (_) {},
    ));
    await tester.pumpAndSettle();
    final footer = tester.widget<Container>(
        find.byKey(const Key('waffra-modern-footer')));
    final decoration = footer.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final text = tester.widget<Text>(find.text('Smart tools'));
    expect(text.style?.color, Colors.white);

    double ratio(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      final bright = x > y ? x : y;
      final dark = x > y ? y : x;
      return (bright + 0.05) / (dark + 0.05);
    }

    for (final background in gradient.colors) {
      expect(ratio(text.style!.color!, background), greaterThanOrEqualTo(4.5),
          reason: 'Footer text must meet WCAG AA normal-text contrast');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('M277: dismissible validation error stays above tappable '
      'footer under dark theme at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notice = ValueNotifier<WaffraNoticeData?>(
      WaffraNoticeData(
        text: 'هذا الحقل مطلوب',
        kind: WaffraSnackKind.error,
        duration: const Duration(seconds: 5),
        requireDismissal: true,
      ),
    );
    addTearDown(notice.dispose);
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Tajawal'),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (context, update) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WaffraFooterNoticeHost(
                  listenable: notice,
                  onDismiss: () => notice.value = null,
                ),
                WaffraFooterNavigation(
                  selectedIndex: selected,
                  english: false,
                  onSelected: (next) => update(() => selected = next),
                ),
              ],
            ),
          )),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final alert = find.byType(WaffraNoticeContent);
    expect(alert, findsOneWidget);
    expect(tester.getRect(alert).bottom, lessThanOrEqualTo(
        tester.getRect(find.byKey(
            const Key('waffra-modern-footer'))).top + 1));
    await tester.tap(find.byKey(const Key('waffra-nav-2')));
    await tester.pumpAndSettle();
    expect(selected, 2, reason: 'An error may not trap footer navigation');
    final closeButton = find.ancestor(
      of: find.descendant(
        of: alert, matching: find.byIcon(Icons.close_rounded)),
      matching: find.byType(IconButton),
    );
    expect(closeButton, findsOneWidget);
    final closeSize = tester.getSize(closeButton);
    expect(closeSize.width, greaterThanOrEqualTo(48),
        reason: 'Error dismissal must have an accessible 48dp target');
    expect(closeSize.height, greaterThanOrEqualTo(48),
        reason: 'Error dismissal must have an accessible 48dp target');
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(notice.value, isNull);
    expect(alert, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

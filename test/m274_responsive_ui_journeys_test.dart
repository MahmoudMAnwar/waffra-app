import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_i18n.dart';

/// E2E-style widget journeys: real tapping/layout, deterministic synthetic UI.
/// Full installed-app Android navigation and finance durability need a separate
/// emulator acceptance test; this file never writes production financial data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    waffraLanguage.value = 'ar';
    hideWaffraAmounts.value = false;
  });
  tearDown(() {
    waffraLanguage.value = 'ar';
    hideWaffraAmounts.value = false;
  });

  for (final width in [320.0, 393.0, 600.0]) {
    for (final english in [false, true]) {
      testWidgets('M274 footer: every destination remains visible and tappable '
          'at ${width.toInt()}px; english=$english', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal'),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
            child: Directionality(
              textDirection: english ? TextDirection.ltr : TextDirection.rtl,
              child: StatefulBuilder(builder: (context, update) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: WaffraFooterNavigation(
                  selectedIndex: selected,
                  english: english,
                  onSelected: (i) => update(() => selected = i),
                ),
              )),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final footer = find.byKey(const Key('waffra-modern-footer'));
        expect(footer, findsOneWidget);
        for (var tab = 0; tab < 5; tab++) {
          final target = find.byKey(Key('waffra-nav-$tab'));
          expect(target, findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.left, greaterThanOrEqualTo(-0.5));
          expect(rect.right, lessThanOrEqualTo(width + 0.5));
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected, tab);
          expect(tester.takeException(), isNull);
        }
        expect(find.byKey(const Key('waffra-nav-5')), findsNothing);
      });
    }
  }

  for (final theme in [Brightness.light, Brightness.dark]) {
    testWidgets('M274 emerald balance stays visible, hide works and does not '
        'alter verified balance at 320px $theme', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var refreshCount = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: theme, useMaterial3: true,
            fontFamily: 'Tajawal'),
        home: Scaffold(body: CustomScrollView(slivers: [
          SliverPersistentHeader(delegate: WaffraBalanceHeader(
            balance: 1250.75,
            english: false,
            monthlyChangePercent: 5.5,
            refreshVerifiedWidgetBalance: () async { refreshCount++; },
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ])),
      ));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('waffra-approved-emerald-balance-card'));
      expect(card, findsOneWidget);
      final bounds = tester.getRect(card);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(find.byKey(const Key('waffra-balance-month-comparison')),
          findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byKey(const Key('waffra-balance-privacy-eye')));
      await tester.pumpAndSettle();
      expect(find.text('***'), findsWidgets);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(refreshCount, 1);
      await tester.tap(find.byKey(const Key('waffra-balance-privacy-eye')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(refreshCount, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('M274 error notice closes without covering footer actions',
      (tester) async {
    final source = ValueNotifier<WaffraNoticeData?>(WaffraNoticeData(
      text: 'هذا الحقل مطلوب',
      kind: WaffraSnackKind.error,
      duration: const Duration(seconds: 5),
      requireDismissal: true,
    ));
    addTearDown(source.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          WaffraFooterNoticeHost(
            listenable: source,
            onDismiss: () => source.value = null,
          ),
          WaffraFooterNavigation(
            selectedIndex: 0, english: false, onSelected: (_) {},
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-modern-footer')), findsOneWidget);
    expect(find.byType(WaffraNoticeContent), findsOneWidget);
    final notice = tester.getRect(find.byType(WaffraNoticeContent));
    final footer = tester.getRect(
        find.byKey(const Key('waffra-modern-footer')));
    expect(notice.bottom, lessThanOrEqualTo(footer.top + 1));
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(source.value, isNull);
    expect(find.byType(WaffraNoticeContent), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

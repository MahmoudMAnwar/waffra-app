import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_i18n.dart';

/// Pixel baselines are generated as **candidates** first and uploaded for
/// design approval. Once committed under baselines/, this same suite compares
/// pixels and fails on unexpected visual changes; never auto-approve a diff.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Tajawal');
    fonts.addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    fonts.addFont(rootBundle.load('assets/fonts/Tajawal-Medium.ttf'));
    fonts.addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await fonts.load();
  });
  setUp(() {
    waffraLanguage.value = 'ar';
    hideWaffraAmounts.value = false;
  });
  tearDown(() {
    hideWaffraAmounts.value = false;
    waffraLanguage.value = 'ar';
  });

  for (final english in [false, true]) {
    for (final dark in [false, true]) {
      final lang = english ? 'en' : 'ar';
      final tone = dark ? 'dark' : 'light';
      testWidgets('Footer golden $lang/$tone at 393px', (tester) async {
        tester.view.physicalSize = const Size(393, 196);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        waffraLanguage.value = lang;
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal',
              brightness: dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: RepaintBoundary(
              key: key,
              child: WaffraFooterNavigation(
                selectedIndex: 2, english: english, onSelected: (_) {},
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(key),
            matchesGoldenFile('baselines/m274-footer-$lang-$tone.png'));
      });
    }
  }

  for (final dark in [false, true]) {
    final tone = dark ? 'dark' : 'light';
    testWidgets('Approved emerald balance golden Arabic/$tone', (tester) async {
      tester.view.physicalSize = const Size(393, 290);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal',
            brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(body: RepaintBoundary(
          key: key,
          child: CustomScrollView(slivers: [
            SliverPersistentHeader(delegate: WaffraBalanceHeader(
              balance: 1250.75,
              english: false,
              monthlyChangePercent: 5.5,
              refreshVerifiedWidgetBalance: () async {},
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ]),
        )),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(key),
          matchesGoldenFile('baselines/m274-balance-ar-$tone.png'));
    });
  }
}

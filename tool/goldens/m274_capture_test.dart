import 'dart:io';
import 'dart:typed_data';

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
    // Flutter tests substitute Ahem for MaterialIcons unless the actual
    // SDK font is loaded. Never approve empty-square icon screenshots.
    Future<ByteData> iconBytes() async {
      try {
        return await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      } catch (_) {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot == null || flutterRoot.isEmpty) {
          throw StateError('MaterialIcons unavailable: FLUTTER_ROOT missing');
        }
        final file = File(
            '$'+'{flutterRoot}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
        final bytes = await file.readAsBytes();
        return ByteData.view(
            bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
      }
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(iconBytes());
    await icons.load();
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
      tester.view.physicalSize = const Size(393, 148);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Tajawal',
            brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(body: RepaintBoundary(
          key: key,
          child: SizedBox(height: 148, child: CustomScrollView(slivers: [
            SliverPersistentHeader(delegate: WaffraBalanceHeader(
              balance: 1250.75,
              english: false,
              monthlyChangePercent: 5.5,
              refreshVerifiedWidgetBalance: () async {},
            )),
          ])),
        )),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(key),
          matchesGoldenFile('baselines/m274-balance-ar-$tone.png'));
    });
  }
}

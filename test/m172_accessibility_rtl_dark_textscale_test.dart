import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_i18n.dart';

/// M172: small isolated widget test, never performs financial persistence.
void main() {
  setUp(() => waffraLanguage.value = 'ar');
  tearDown(() => waffraLanguage.value = 'ar');

  testWidgets('Arabic/English text stays Tajawal, readable at 175% in light/dark',
      (tester) async {
    for (final language in ['ar', 'en']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        waffraLanguage.value = language;
        final direction = language == 'ar'
            ? TextDirection.rtl : TextDirection.ltr;
        final expected = language == 'ar' ? 'المعاملات' : 'Transactions';
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            useMaterial3: true, brightness: Brightness.light, fontFamily: 'Tajawal',
          ),
          darkTheme: ThemeData(
            useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Tajawal',
          ),
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.75),
            ),
            child: Directionality(
              textDirection: direction,
              child: const Scaffold(
                body: Center(child: WaffraText('المعاملات')),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final translatedText = find.byWidgetPredicate(
          // WaffraText extends Text; match only the rendered leaf Text, not its wrapper.
          (widget) => widget is Text && widget is! WaffraText && widget.data == expected,
        );
        expect(translatedText, findsOneWidget);
        final context = tester.element(translatedText);
        expect(Directionality.of(context), direction);
        expect(MediaQuery.textScalerOf(context).scale(16), closeTo(28, 0.001));
        expect(Theme.of(context).brightness, brightness);
        final rendered = tester.widget<Text>(translatedText);
        expect(rendered.style?.fontFamily, 'Tajawal');
      }
    }
  });

  test('language switch affects visible translations, not underlying finance key', () {
    const stored = 'المعاملات';
    expect(waffraTr(stored), stored);
    waffraLanguage.value = 'en';
    expect(waffraTr(stored), 'Transactions');
    expect(stored, 'المعاملات');
  });

  test('production theme retains black-ish dark background and system choice',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('scaffoldBackgroundColor:const Color(0xFF080A09)'));
    expect(source, contains("themeMode:appearance=='system'?ThemeMode.system"));
    expect(source, contains("textDirection:language=='ar'?TextDirection.rtl:TextDirection.ltr"));
    expect(source, contains("fontFamily:'Tajawal'"));
    expect(source, contains('accessibilityFeatures.disableAnimations'));
    expect(source, contains("'off'=>0.0"));
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/currency_converter.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_gold_market_data.dart';
import 'package:waffra/waffra_gold_market_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M225 every selectable FX currency has a country flag or honest EUR icon', () {
    final source=File('lib/currency_converter.dart').readAsStringSync();
    for (final code in waffraCountryCurrencies.map((item) => item.code)) {
      final flag=waffraCurrencyFlag(code);
      expect(flag, isNot('💱'), reason: 'Missing flag for $code');
      expect(flag.isNotEmpty, isTrue);
    }
    expect(waffraCurrencyFlag('SAR'), '🇸🇦');
    expect(waffraCurrencyFlag('EGP'), '🇪🇬');
    expect(waffraCurrencyFlag('USD'), '🇺🇸');
    expect(waffraCurrencyFlag('EUR'), '💶');
    expect(source,contains('leading:Text(waffraCurrencyFlag(code)'));
    expect(source,contains('_currencyChoice(from)'));
    expect(source,contains('_currencyChoice(to!)'));
    expect(source,contains('محوّل العملات وأسعار الذهب العالمية'));
  });

  testWidgets('M225 gold card renders a real USD spot across three premium karat tiles',
      (tester) async {
    final quote = WaffraGoldSpotQuote(
      usdPerTroyOunce: 3240.45,
      updatedAtUtc: DateTime.now().toUtc(),
      source: 'synthetic-test-only',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: WaffraGoldMarketSection(
          english: false, loadSpot: () async => quote,
        ))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('waffra-world-gold-ounce')), findsOneWidget);
    expect(find.byKey(const Key('waffra-gold-karat-24-price')), findsOneWidget);
    expect(find.byKey(const Key('waffra-gold-karat-22-price')), findsOneWidget);
    expect(find.byKey(const Key('waffra-gold-karat-21-price')), findsOneWidget);
    expect(find.text('عيار 24'), findsWidgets);
    expect(find.text('عيار 22'), findsWidgets);
    expect(find.text('عيار 21'), findsWidgets);
    final source=File('lib/waffra_gold_market_section.dart').readAsStringSync();
    expect(source,contains('_drawBar(canvas'));
    expect(source,contains('size.maxWidth >= 285 ? 3 : 2'));
    expect(source,contains('واحد'), isFalse);
  });
}

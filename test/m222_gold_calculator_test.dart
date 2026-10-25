import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waffra/waffra_gold_calculator.dart';

void main() {
  test('troy ounces, karats, grams, SAR and EGP are mathematically consistent', () {
    const ounce = WaffraGoldMath.troyOunceGrams;
    expect(WaffraGoldMath.perGram(ounce * 100, 24, 1), closeTo(100, 1e-9));
    expect(WaffraGoldMath.perGram(ounce * 100, 21, 1), closeTo(87.5, 1e-9));
    expect(WaffraGoldMath.perGram(ounce * 100, 18, 3.75), closeTo(281.25, 1e-9));
    expect(WaffraGoldMath.total(87.5, 2.5), closeTo(218.75, 1e-9));
    expect(WaffraGoldMath.perGram(ounce * 100, 22, 50),
        closeTo((22 / 24) * 5000, 1e-8));
  });

  test('unavailable prices, bad karats or invalid weights cannot be quoted', () {
    expect(() => WaffraGoldMath.perGram(0, 21, 3.75), throwsFormatException);
    expect(() => WaffraGoldMath.perGram(100, 20, 3.75), throwsFormatException);
    expect(() => WaffraGoldMath.perGram(double.nan, 24, 1), throwsFormatException);
    expect(() => WaffraGoldMath.total(10, 0), throwsFormatException);
    expect(() => WaffraGoldMath.total(10, double.infinity), throwsFormatException);
  });

  test('real API schema: gold USD/troy oz and single-base USD to SAR and EGP', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    final api = MockClient((request) async {
      switch (request.url.host) {
        case 'api.gold-api.com':
          expect(request.url.path, '/price/XAU');
          return http.Response(jsonEncode({
            'symbol': 'XAU', 'currency': 'USD',
            'price': WaffraGoldMath.troyOunceGrams * 100,
            'updatedAt': now,
          }), 200);
        case 'open.er-api.com':
          expect(request.url.path, '/v6/latest/USD');
          return http.Response(jsonEncode({
            'result': 'success', 'rates': {
              'SAR': 3.75, 'EGP': 50.0, 'USD': 1.0,
            }, 'time_last_update_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          }), 200);
        default: throw StateError('Unexpected endpoint');
      }
    });
    final quote = await const WaffraGoldPriceService().load('EGP', client: api);
    expect(quote.gram(24), closeTo(5000, 1e-5));
    expect(quote.gram(24, sar: true), closeTo(375, 1e-5));
    expect(quote.gram(21), closeTo(4375, 1e-5));
    expect(quote.currencyFx / quote.sarFx, closeTo(50 / 3.75, 1e-5));
    api.close();
  });

  test('FX backup works for supported codes without guessing', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'api.gold-api.com') {
        return http.Response(jsonEncode({
          'symbol': 'XAU', 'currency': 'USD',
          'price': 3000,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }), 200);
      }
      if (req.url.host == 'open.er-api.com') return http.Response('offline', 503);
      return http.Response(jsonEncode({
        'usd': {'sar': 3.75, 'egp': 48.5, 'jpy': 150},
        'date': DateTime.now().toUtc().toIso8601String().split('T').first,
      }), 200);
    });
    final result = await const WaffraGoldPriceService().load('JPY', client: client);
    expect(result.currencyFx, 150);
    expect(result.sarFx, 3.75);
    client.close();
  });

  test('wrong XAU unit, stale timestamps, missing currencies fail closed', () async {
    final bad = MockClient((req) async => http.Response(jsonEncode({
      'symbol': 'XAU', 'currency': 'EGP', 'price': 3000,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }), 200));
    await expectLater(const WaffraGoldPriceService().load('EGP', client: bad),
        throwsFormatException);
    bad.close();

    final missing = MockClient((req) async {
      if (req.url.host == 'api.gold-api.com') {
        return http.Response(jsonEncode({
          'symbol': 'XAU', 'currency': 'USD', 'price': 3000,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }), 200);
      }
      return http.Response(jsonEncode({
        'result': 'success', 'rates': {'SAR': 3.75},
        'time_last_update_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      }), 200);
    });
    await expectLater(const WaffraGoldPriceService().load('EGP', client: missing),
        throwsFormatException);
    missing.close();
  });

  testWidgets('gold calculator contains AR-friendly gold controls without live network', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WaffraGoldCalculatorPage(
      arabicCurrencies: {'SAR': 'ريال سعودي', 'EGP': 'جنيه مصري'},
      englishCurrencies: {'SAR': 'Saudi riyal', 'EGP': 'Egyptian pound'},
    )));
    expect(find.byKey(const Key('waffra-gold-currency-picker')), findsOneWidget);
    expect(find.byKey(const Key('waffra-gold-quote-button')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    // No network request unless quote button is tapped.
  });

  test('currency converter opens new gold route; release notes are required', () {
    final converter = File('lib/currency_converter.dart').readAsStringSync();
    final notes = File('docs/release/WAFFRA_APPROVED_CHANGES.txt').readAsStringSync();
    expect(converter, contains("Key('waffra-open-gold-calculator')"));
    expect(converter, contains('WaffraGoldCalculatorPage('));
    expect(notes, contains('M222'));
    expect(notes, contains('أسعار الذهب'));
  });
}

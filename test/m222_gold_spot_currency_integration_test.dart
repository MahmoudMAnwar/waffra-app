import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waffra/waffra_gold_market_data.dart';
import 'package:waffra/waffra_gold_market_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> quotePayload({double price = 3100, DateTime? stamp}) =>
      <String, dynamic>{
        'symbol': 'XAU', 'currency': 'USD', 'price': price,
        'updatedAt': (stamp ?? DateTime.now().toUtc()).toIso8601String(),
      };

  test('M222 validates official XAU/USD shape with spot USD per troy ounce', () {
    final quote = WaffraGoldSpotQuote.fromJson(quotePayload());
    expect(quote.usdPerTroyOunce, 3100);
    expect(quote.source, 'Gold-API');
    expect(quote.updatedAtUtc.isUtc, isTrue);
  });

  test('M222 uses exactly one troy ounce, not everyday ounce grams', () {
    final quote = WaffraGoldSpotQuote.fromJson(quotePayload());
    expect(waffraTroyOunceGrams, 31.1034768);
    expect(quote.pureGramUsd * waffraTroyOunceGrams, closeTo(3100, 0.00001));
    expect(quote.gramUsd(21), closeTo(quote.pureGramUsd * .875, 0.00001));
    expect(quote.gramUsd(18), closeTo(quote.pureGramUsd * .75, 0.00001));
  });

  test('M222 karat calculations include 24 22 21 18 14 and fineness', () {
    final quote = WaffraGoldSpotQuote.fromJson(quotePayload());
    expect(waffraGoldFineness.keys.toList(), [24, 22, 21, 18, 14]);
    for (final k in waffraGoldFineness.keys) {
      expect(quote.gramUsd(k), greaterThan(0));
      expect(quote.gramUsd(k), lessThanOrEqualTo(quote.pureGramUsd));
    }
    expect(() => quote.gramUsd(10), throwsArgumentError);
  });

  test('M222 bullion values and gold value scale with selected mass', () {
    final quote = WaffraGoldSpotQuote.fromJson(quotePayload());
    expect(quote.estimateUsd(karat: 24, grams: 10),
        closeTo(quote.gramUsd(24) * 10, 0.00001));
    expect(quote.estimateUsd(karat: 21, grams: 15),
        closeTo(quote.gramUsd(21) * 15, 0.00001));
    for (final g in [double.nan, double.infinity, -5.0, 0.0, 1000001.0]) {
      expect(() => quote.estimateUsd(karat: 21, grams: g),
          throwsArgumentError);
    }
  });

  test('M222 rejects non-gold/non-USD and missing currency', () {
    for (final mismatch in <Map<String, dynamic>>[
      {...quotePayload(), 'symbol': 'XAG'},
      {...quotePayload(), 'currency': 'SAR'},
      {...quotePayload()}..remove('currency'),
    ]) {
      expect(() => WaffraGoldSpotQuote.fromJson(mismatch),
          throwsFormatException);
    }
  });

  test('M222 refuses missing, nonpositive and nonfinite prices', () {
    for (final raw in <Object?>[null, 0, -1, '3100', double.nan,
        double.infinity, 1000001]) {
      expect(() => WaffraGoldSpotQuote.fromJson(
        {...quotePayload(), 'price': raw},
      ), throwsFormatException);
    }
  });

  test('M222 rejects future timestamp, old timestamp and zoneless time', () {
    for (final raw in <String>[
      DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
      DateTime.now().toUtc().subtract(const Duration(days: 8)).toIso8601String(),
      '2026-10-25T10:00:00',
      'not-a-time',
    ]) {
      expect(() => WaffraGoldSpotQuote.fromJson(
        {...quotePayload(), 'updatedAt': raw},
      ), throwsFormatException);
    }
  });

  test('M222 HTTP client receives one public HTTPS XAU request, no key', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'api.gold-api.com');
      expect(request.url.path, '/price/XAU');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers.containsKey('x-api-key'), isFalse);
      return http.Response(jsonEncode(quotePayload()), 200);
    });
    try {
      final quote = await const WaffraGoldSpotService().fetch(client: client);
      expect(requests, 1);
      expect(quote.usdPerTroyOunce, 3100);
    } finally {
      client.close();
    }
  });

  test('M222 never fabricates a gold price for HTTP failures', () async {
    for (final status in [401, 429, 500, 503]) {
      final client = MockClient((_) async => http.Response('unavailable', status));
      try {
        await expectLater(const WaffraGoldSpotService().fetch(client: client),
            throwsA(isA<Exception>()));
      } finally {
        client.close();
      }
    }
  });

  test('M222 rejects huge/unparseable provider payloads', () async {
    final oversized = MockClient(
      (_) async => http.Response('a' * 131073, 200),
    );
    final malformed = MockClient((_) async => http.Response('[]', 200));
    try {
      await expectLater(const WaffraGoldSpotService().fetch(client: oversized),
          throwsA(isA<Exception>()));
      await expectLater(const WaffraGoldSpotService().fetch(client: malformed),
          throwsFormatException);
    } finally {
      oversized.close();
      malformed.close();
    }
  });

  testWidgets('M222 gold market initially has no fabricated price',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: WaffraGoldMarketSection(
        english: false,
        loadSpot: () async {
          throw const FormatException('Synthetic connection down');
        },
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('أسعار الذهب العالمية'), findsOneWidget);
    expect(find.text('سعر الأونصة العالمي'), findsOneWidget);
    expect(find.byKey(const Key('waffra-gold-quote-error')), findsOneWidget);
    expect(find.text('3,183.20'), findsNothing);
  });

  testWidgets('M222 renders real spot values and gold purity cards',
      (tester) async {
    final synthetic = WaffraGoldSpotQuote.fromJson(quotePayload());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: WaffraGoldMarketSection(
        english: false, loadSpot: () async => synthetic,
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('أسعار الذهب العالمية'), findsOneWidget);
    expect(find.byKey(const Key('waffra-world-gold-ounce')), findsOneWidget);
    for (final k in [24, 22, 21, 18, 14]) {
      expect(find.byKey(Key('waffra-gold-karat-$k-price')), findsOneWidget);
    }
    expect(find.text('3100.00'), findsNothing); // USD prefix is mandatory
  });

  testWidgets('M222 English gold market labels appear without placeholders',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: WaffraGoldMarketSection(
        english: true, loadSpot: () async => WaffraGoldSpotQuote.fromJson(quotePayload()),
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Global gold prices'), findsOneWidget);
    expect(find.text('Gold karats'), findsOneWidget);
  });
}

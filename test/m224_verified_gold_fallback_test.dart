import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waffra/waffra_gold_market_data.dart';
import 'package:waffra/waffra_gold_calculator.dart';

void main() {
  Map<String, dynamic> independentQuote({String? stamp}) => {
    'spot_usd_oz': 3110.35,
    'xau': {'price': 3110.35, 'currency': 'USD', 'unit': 'oz'},
    'data_state': {
      'status': 'fresh', 'source': 'upstream',
      'as_of': stamp ?? DateTime.now().toUtc().toIso8601String(),
    },
  };

  test('M224 primary source down -> independent validated XAU/USD source', () async {
    final seen = <String>[];
    final client = MockClient((r) async {
      seen.add(r.url.host);
      expect(r.url.scheme, 'https');
      expect(r.headers.containsKey('Authorization'), isFalse);
      if (r.url.host == 'api.gold-api.com') {
        return http.Response('Service unavailable', 503);
      }
      expect(r.url.host, 'xaus.com');
      expect(r.url.path, '/api/v1/spot');
      expect(r.url.queryParameters['currency'], 'USD');
      expect(r.url.queryParameters['unit'], 'oz');
      return http.Response(jsonEncode(independentQuote()), 200);
    });
    final result = await const WaffraGoldSpotService().fetch(client: client);
    expect(result.usdPerTroyOunce, 3110.35);
    expect(result.source, 'XAUS');
    expect(seen, ['api.gold-api.com', 'xaus.com']);
    client.close();
  });

  test('M224 rejects inconsistent quote, wrong unit and old source time', () {
    final invalid = [
      {...independentQuote(), 'spot_usd_oz': 3200},
      {...independentQuote(), 'xau': {'price': 3110.35, 'currency': 'USD', 'unit': 'gram'}},
      independentQuote(stamp: DateTime.now().toUtc()
          .subtract(const Duration(days: 8)).toIso8601String()),
      {...independentQuote(), 'data_state': {
        'status': 'unavailable', 'source': 'cache',
        'as_of': DateTime.now().toUtc().toIso8601String(),
      }},
    ];
    for (final body in invalid) {
      expect(() => WaffraGoldSpotQuote.fromXausJson(body), throwsFormatException);
    }
  });

  test('M224 refuses both feeds offline; no fake gold price', () async {
    final client = MockClient((_) async => http.Response('offline', 503));
    try {
      await expectLater(const WaffraGoldSpotService().fetch(client: client),
          throwsA(isA<HttpException>()));
    } finally { client.close(); }
  });

  test('M224 gold conversion uses validated fallback plus genuine USD FX', () async {
    final client = MockClient((r) async {
      if (r.url.host == 'api.gold-api.com') return http.Response('offline', 503);
      if (r.url.host == 'xaus.com') {
        return http.Response(jsonEncode(independentQuote()), 200);
      }
      expect(r.url.host, 'open.er-api.com');
      return http.Response(jsonEncode({
        'result': 'success',
        'rates': {'SAR': 3.75, 'EGP': 50.0, 'USD': 1.0},
        'time_last_update_unix': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      }), 200);
    });
    final quote=await const WaffraGoldPriceService().load('EGP',client:client);
    expect(quote.gram(24, sar:true), greaterThan(0));
    expect(quote.gram(24), closeTo(quote.gram(24, sar:true)*50/3.75,0.00001));
    client.close();
  });

  test('M225 XAUS published troy_oz and oz names both mean one troy ounce', () async {
    for (final unit in const ['oz', 'troy_oz']) {
      final response = independentQuote();
      (response['xau'] as Map<String, dynamic>)['unit'] = unit;
      final client = MockClient((request) async {
        if (request.url.host == 'api.gold-api.com') {
          return http.Response('temporary outage', 503);
        }
        expect(request.url.host, 'xaus.com');
        expect(request.url.queryParameters['unit'], 'oz');
        return http.Response(jsonEncode(response), 200);
      });
      try {
        final quote = await const WaffraGoldSpotService().fetch(client: client);
        expect(quote.usdPerTroyOunce, closeTo(3110.35, 0.001));
        expect(quote.pureGramUsd, closeTo(3110.35 / waffraTroyOunceGrams, 0.001));
        expect(quote.source, 'XAUS');
      } finally { client.close(); }
    }
  });

  test('M225 last verified gold quote is safe to display offline only with'
       ' authentic timestamp and permitted XAU/USD shape', () {
    final now = DateTime.utc(2026, 10, 25, 12);
    final quote = WaffraGoldSpotQuote(
      usdPerTroyOunce: 3110.35,
      updatedAtUtc: now.subtract(const Duration(hours: 2)),
      source: 'Gold-API',
    );
    final cache = Map<String, dynamic>.from(quote.toCacheJson());
    final restored = WaffraGoldSpotQuote.fromCacheJson(cache, checkedAt: now);
    expect(restored.usdPerTroyOunce, quote.usdPerTroyOunce);
    expect(restored.updatedAtUtc, quote.updatedAtUtc);
    expect(restored.source, 'verified-cache');
    expect(() => WaffraGoldSpotQuote.fromCacheJson({
      ...cache, 'updatedAt': now.subtract(const Duration(days: 9)).toIso8601String(),
    }, checkedAt: now), throwsFormatException);
    expect(() => WaffraGoldSpotQuote.fromCacheJson({
      ...cache, 'currency': 'EGP',
    }, checkedAt: now), throwsFormatException);
    expect(() => WaffraGoldSpotQuote.fromCacheJson({
      ...cache, 'price': double.nan,
    }, checkedAt: now), throwsFormatException);
  });

}

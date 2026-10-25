import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// ISO troy ounce (not the 28.35 g everyday ounce).
const double waffraTroyOunceGrams = 31.1034768;

/// Typical fine metal content; commercial retail premiums and VAT excluded.
const Map<int, double> waffraGoldFineness = <int, double>{
  24: 0.999,
  22: 22 / 24,
  21: 21 / 24,
  18: 18 / 24,
  14: 14 / 24,
};

/// A price in USD per troy ounce from an independently sourced spot feed.
/// Values are indicative metal values, not tradeable quotes or a jeweller's ask.
class WaffraGoldSpotQuote {
  final double usdPerTroyOunce;
  final DateTime updatedAtUtc;
  final String source;
  const WaffraGoldSpotQuote({
    required this.usdPerTroyOunce,
    required this.updatedAtUtc,
    required this.source,
  });

  factory WaffraGoldSpotQuote.fromJson(
    Map<String, dynamic> json, {
    DateTime? checkedAt,
  }) {
    if (json['symbol'] != 'XAU' || json['currency'] != 'USD') {
      throw const FormatException('Gold response is not XAU/USD spot.');
    }
    final raw = json['price'];
    final stamp = json['updatedAt'];
    if (raw is! num || !raw.toDouble().isFinite ||
        raw.toDouble() <= 0 || raw.toDouble() > 1000000 ||
        stamp is! String ||
        !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(stamp)) {
      throw const FormatException('Gold price or UTC update time missing.');
    }
    final updated = DateTime.tryParse(stamp)?.toUtc();
    final now = (checkedAt ?? DateTime.now()).toUtc();
    if (updated == null ||
        updated.isAfter(now.add(const Duration(minutes: 10))) ||
        now.difference(updated) > const Duration(days: 7)) {
      throw const FormatException('Gold price is invalid or too old.');
    }
    return WaffraGoldSpotQuote(
      usdPerTroyOunce: raw.toDouble(),
      updatedAtUtc: updated,
      source: 'Gold-API',
    );
  }

  factory WaffraGoldSpotQuote.fromXausJson(
    Map<String, dynamic> json, {DateTime? checkedAt}
  ) {
    final gold = json['xau'];
    final state = json['data_state'];
    if (gold is! Map || state is! Map ||
        gold['currency'] != 'USD' || gold['unit'] != 'oz' ||
        !const <String>['fresh', 'stale'].contains(state['status']) ||
        !const <String>['upstream', 'cache'].contains(state['source'])) {
      throw const FormatException('Unverified XAU/USD spot source.');
    }
    final price = gold['price'], other = json['spot_usd_oz'];
    final stamp = state['as_of'];
    if (price is! num || other is! num ||
        !price.toDouble().isFinite || price <= 0 || price > 1000000 ||
        !other.toDouble().isFinite ||
        (price.toDouble() - other.toDouble()).abs() > 0.02 ||
        stamp is! String ||
        !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(stamp)) {
      throw const FormatException('Gold spot price, source unit or UTC invalid.');
    }
    final updated = DateTime.tryParse(stamp)?.toUtc();
    final now = (checkedAt ?? DateTime.now()).toUtc();
    if (updated == null ||
        updated.isAfter(now.add(const Duration(minutes: 10))) ||
        now.difference(updated) > const Duration(days: 7)) {
      throw const FormatException('Independent source spot time is stale.');
    }
    return WaffraGoldSpotQuote(
      usdPerTroyOunce: price.toDouble(),
      updatedAtUtc: updated,
      source: 'XAUS',
    );
  }

  double get pureGramUsd => usdPerTroyOunce / waffraTroyOunceGrams;

  double gramUsd(int karat) {
    final fineness = waffraGoldFineness[karat];
    if (fineness == null) {
      throw ArgumentError.value(karat, 'karat', 'Unsupported gold purity');
    }
    return pureGramUsd * fineness;
  }

  /// Bullion and jewellery estimator: only raw gold content, no premium,
  /// workmanship, spreads, taxes or shipping.
  double estimateUsd({required int karat, required double grams}) {
    if (!grams.isFinite || grams <= 0 || grams > 1000000) {
      throw ArgumentError.value(grams, 'grams', 'Invalid gold weight');
    }
    return gramUsd(karat) * grams;
  }

  bool isOlderThan(Duration threshold, DateTime now) =>
      now.toUtc().difference(updatedAtUtc) > threshold;
}

class WaffraGoldSpotService {
  const WaffraGoldSpotService();

  static final Uri endpoint = Uri.https('api.gold-api.com', '/price/XAU');
  static final Uri fallbackEndpoint = Uri.https(
      'xaus.com', '/api/v1/spot', {'currency':'USD','unit':'oz','compact':'1'});

  Future<WaffraGoldSpotQuote> fetch({http.Client? client}) async {
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      // Prefer the primary provider. Never substitute a fabricated quote.
      try {
        final response = await httpClient.get(
          endpoint, headers: const <String, String>{'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200 || response.bodyBytes.length > 131072) {
          throw const HttpException('Gold spot source unavailable.');
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Invalid gold spot data.');
        }
        return WaffraGoldSpotQuote.fromJson(json);
      } catch (_) {
        // Backup has independently verified units and source timestamp.
        final response = await httpClient.get(
          fallbackEndpoint, headers: const <String, String>{'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200 || response.bodyBytes.length > 131072) {
          throw const HttpException('Independent gold source unavailable.');
        }
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Independent gold source invalid.');
        }
        return WaffraGoldSpotQuote.fromXausJson(json);
      }
    } finally {
      if (owned) httpClient.close();
    }
  }
}

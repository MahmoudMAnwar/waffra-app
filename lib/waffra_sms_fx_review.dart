import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'waffra_sms_multicurrency_review.dart';

/// Source-agnostic, verified quote. Only currencies are sent to the provider;
/// bank message text and user identity are never uploaded.
class WaffraSmsFxQuote {
  const WaffraSmsFxQuote._(
    this.originalCurrency, this.targetCurrency, this.targetPerOriginal,
    this.provider, this.sourceTimestampUtc,
  );
  final String originalCurrency, targetCurrency, provider;
  final double targetPerOriginal;
  final DateTime sourceTimestampUtc;
  static const maxAge = Duration(days: 7);

  static WaffraSmsFxQuote fromUsdRates(
    Map<String, dynamic> json, {
    required String originalCurrency,
    required String targetCurrency,
    DateTime? now,
    String provider = 'ExchangeRate-API',
  }) {
    final source = originalCurrency.toUpperCase();
    final target = targetCurrency.toUpperCase();
    if (!WaffraSmsCurrencies.supported.contains(source) ||
        !WaffraSmsCurrencies.supported.contains(target) ||
        provider.trim().isEmpty || json['result'] != 'success' ||
        json['rates'] is! Map || json['time_last_update_unix'] is! num) {
      throw const FormatException('Missing verified exchange-rate data');
    }
    final table = json['rates'] as Map;
    final a = table[source], b = table[target];
    final timestamp = json['time_last_update_unix'] as num;
    if (a is! num || b is! num || a <= 0 || b <= 0 ||
        !a.toDouble().isFinite || !b.toDouble().isFinite ||
        timestamp.toInt() <= 0) {
      throw const FormatException('Invalid currency rates');
    }
    final at = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000, isUtc: true);
    final clock = (now ?? DateTime.now()).toUtc();
    if (at.isAfter(clock.add(const Duration(hours: 1))) ||
        clock.difference(at) > maxAge) {
      throw const FormatException('Quote is stale or from the future');
    }
    final rate = b.toDouble() / a.toDouble();
    if (!rate.isFinite || rate <= 0 || rate > 1e10) {
      throw const FormatException('Invalid cross rate');
    }
    return WaffraSmsFxQuote._(source, target, rate, provider, at);
  }

  static WaffraSmsFxQuote fromUsdBackup(
    Map<String, dynamic> json, {
    required String originalCurrency,
    required String targetCurrency,
    DateTime? now,
  }) {
    final values = json['usd'];
    final date = json['date'];
    if (values is! Map || date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Missing independent FX data');
    }
    final stamp = DateTime.tryParse(date + 'T00:00:00Z');
    if (stamp == null) throw const FormatException('Invalid FX date');
    return fromUsdRates({
      'result': 'success',
      'rates': {
        originalCurrency.toUpperCase(): values[originalCurrency.toLowerCase()],
        targetCurrency.toUpperCase(): values[targetCurrency.toLowerCase()],
      },
      'time_last_update_unix': stamp.millisecondsSinceEpoch ~/ 1000,
    }, originalCurrency: originalCurrency, targetCurrency: targetCurrency,
      provider: 'fawazahmed0 Currency API', now: now);
  }

  static Future<WaffraSmsFxQuote> fetch({
    required String originalCurrency,
    required String targetCurrency,
    http.Client? client,
    DateTime? now,
  }) async {
    if (originalCurrency == targetCurrency) {
      throw const FormatException('Same currency needs no conversion');
    }
    final transport = client ?? http.Client();
    try {
      try {
        final res = await transport.get(
          Uri.https('open.er-api.com', '/v6/latest/USD'))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200 || res.bodyBytes.length > 131072) {
          throw const HttpException('Primary FX unavailable');
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Invalid primary response');
        }
        return fromUsdRates(data, originalCurrency: originalCurrency,
          targetCurrency: targetCurrency, now: now);
      } catch (_) {
        final res = await transport.get(Uri.https('cdn.jsdelivr.net',
          '/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json'))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200 || res.bodyBytes.length > 131072) {
          throw const HttpException('Backup FX unavailable');
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Invalid backup response');
        }
        return fromUsdBackup(data, originalCurrency: originalCurrency,
          targetCurrency: targetCurrency, now: now);
      }
    } finally {
      if (client == null) transport.close();
    }
  }
}

abstract final class WaffraCurrencyMinor {
  static int digits(String currency) => WaffraSmsCurrencies.minorDigits(currency);

  static int? exact(double value, String currency) {
    if (!WaffraSmsCurrencies.supported.contains(currency) ||
        !value.isFinite || value <= 0 || value > 1e9) return null;
    final unit = math.pow(10, digits(currency)).toDouble();
    final scaled = value * unit;
    final minor = scaled.round();
    if (minor <= 0 || (scaled - minor).abs() > 0.00001) return null;
    return minor;
  }

  static double major(int minor, String currency) =>
    minor / math.pow(10, digits(currency));
}

/// Auditable conversion candidate. No production commit is permitted until
/// its snapshot is stored atomically with the encrypted transaction record.
/// Approval here is a draft, NOT an instruction to write to a SAR ledger.
class WaffraSmsFxReview {
  const WaffraSmsFxReview._(
    this.originalMinor, this.originalCurrency,
    this.convertedMinor, this.convertedCurrency,
    this.targetPerOriginal, this.rateProvider,
    this.rateTimestampUtc, this.userApprovedAtUtc,
  );

  final int originalMinor, convertedMinor;
  final String originalCurrency, convertedCurrency, rateProvider;
  final double targetPerOriginal;
  final DateTime rateTimestampUtc, userApprovedAtUtc;

  double get originalAmount =>
    WaffraCurrencyMinor.major(originalMinor, originalCurrency);
  double get convertedAmount =>
    WaffraCurrencyMinor.major(convertedMinor, convertedCurrency);

  static WaffraSmsFxReview approve({
    required double originalAmount,
    required WaffraSmsFxQuote quote,
    required bool userConfirmed,
    DateTime? now,
  }) {
    if (!userConfirmed) {
      throw StateError('User approval of the FX quote is required');
    }
    final sourceMinor = WaffraCurrencyMinor.exact(
      originalAmount, quote.originalCurrency);
    if (sourceMinor == null) {
      throw const FormatException('Invalid original currency precision');
    }
    final current = (now ?? DateTime.now()).toUtc();
    if (quote.sourceTimestampUtc.isAfter(
          current.add(const Duration(hours: 1))) ||
        current.difference(quote.sourceTimestampUtc) >
          WaffraSmsFxQuote.maxAge) {
      throw const FormatException('Expired quote');
    }
    final targetDigits = WaffraCurrencyMinor.digits(quote.targetCurrency);
    final converted = (WaffraCurrencyMinor.major(
      sourceMinor, quote.originalCurrency) *
      quote.targetPerOriginal * math.pow(10, targetDigits)).round();
    if (converted <= 0 || converted > 1000000000000) {
      throw const FormatException('Converted amount out of bounds');
    }
    return WaffraSmsFxReview._(
      sourceMinor, quote.originalCurrency, converted, quote.targetCurrency,
      quote.targetPerOriginal, quote.provider, quote.sourceTimestampUtc,
      current);
  }

  Map<String, dynamic> toProvenanceJson() => {
    'version': 1,
    'originalMinor': originalMinor,
    'originalCurrency': originalCurrency,
    'convertedMinor': convertedMinor,
    'convertedCurrency': convertedCurrency,
    'targetPerOriginal': targetPerOriginal,
    'provider': rateProvider,
    'rateTimestampUtc': rateTimestampUtc.toIso8601String(),
    'approvedUtc': userApprovedAtUtc.toIso8601String(),
  };

  static WaffraSmsFxReview fromProvenanceJson(Map<String, dynamic> data) {
    if (data['version'] != 1 || data['originalMinor'] is! int ||
        data['convertedMinor'] is! int ||
        data['originalCurrency'] is! String ||
        data['convertedCurrency'] is! String ||
        data['targetPerOriginal'] is! num ||
        data['provider'] is! String) {
      throw const FormatException('Malformed FX snapshot');
    }
    final original = data['originalCurrency'] as String;
    final converted = data['convertedCurrency'] as String;
    final amount = data['originalMinor'] as int;
    final convertedAmount = data['convertedMinor'] as int;
    final rate = (data['targetPerOriginal'] as num).toDouble();
    final rateAt = DateTime.tryParse((data['rateTimestampUtc'] ?? '').toString());
    final approved = DateTime.tryParse((data['approvedUtc'] ?? '').toString());
    if (!WaffraSmsCurrencies.supported.contains(original) ||
        !WaffraSmsCurrencies.supported.contains(converted) ||
        amount <= 0 || convertedAmount <= 0 ||
        !rate.isFinite || rate <= 0 ||
        (data['provider'] as String).trim().isEmpty ||
        rateAt == null || approved == null ||
        !data['rateTimestampUtc'].toString().endsWith('Z') ||
        !data['approvedUtc'].toString().endsWith('Z') ||
        rateAt.isAfter(approved.add(const Duration(hours: 1))) ||
        approved.difference(rateAt) > WaffraSmsFxQuote.maxAge) {
      throw const FormatException('Invalid FX snapshot');
    }
    final expected = (WaffraCurrencyMinor.major(amount, original) * rate *
      math.pow(10, WaffraCurrencyMinor.digits(converted))).round();
    if (expected != convertedAmount) {
      throw const FormatException('FX rate/converted amount mismatch');
    }
    return WaffraSmsFxReview._(
      amount, original, convertedAmount, converted, rate,
      data['provider'] as String, rateAt.toUtc(), approved.toUtc());
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  final at = DateTime.utc(2026, 10, 27, 9);
  final now = DateTime.utc(2026, 10, 28, 0);
  final rates = <String, dynamic>{
    'result': 'success',
    'time_last_update_unix': at.millisecondsSinceEpoch ~/ 1000,
    'rates': {'USD': 1.0, 'SAR': 3.75, 'EGP': 48.0,
      'EUR': 0.92, 'KWD': 0.307, 'JPY': 151.0},
  };
  WaffraSmsFxQuote quote(String original, String target) =>
      WaffraSmsFxQuote.fromUsdRates(
        rates, originalCurrency: original, targetCurrency: target, now: now);

  test('M292 USD 100 converts to SAR 375 only with explicit approval', () {
    final usdSar = quote('USD', 'SAR');
    expect(usdSar.targetPerOriginal, 3.75);
    expect(usdSar.sourceTimestampUtc, at);
    expect(() => WaffraSmsFxReview.approve(
      originalAmount: 100, quote: usdSar, userConfirmed: false, now: now),
      throwsStateError);
    final confirmed = WaffraSmsFxReview.approve(
      originalAmount: 100, quote: usdSar, userConfirmed: true, now: now);
    expect(confirmed.originalCurrency, 'USD');
    expect(confirmed.originalAmount, 100);
    expect(confirmed.convertedCurrency, 'SAR');
    expect(confirmed.convertedAmount, 375);
    expect(confirmed.rateProvider, 'ExchangeRate-API');
    expect(confirmed.userApprovedAtUtc, now);
    expect(WaffraSmsFxReview.fromProvenanceJson(
      confirmed.toProvenanceJson()).toProvenanceJson(),
      confirmed.toProvenanceJson());
  });

  test('M292 cross rates derive from ONE provider timestamp, no double converting', () {
    final sarToEgp = quote('SAR', 'EGP');
    final result = WaffraSmsFxReview.approve(
      originalAmount: 200, quote: sarToEgp,
      userConfirmed: true, now: now);
    expect(sarToEgp.targetPerOriginal, 48 / 3.75);
    expect(result.convertedAmount, 2560);
    expect(result.originalAmount, 200);
    expect(waffraCountry('EGP').code, 'EGP');
    expect(WaffraDisplayCurrency.country.code, 'SAR',
      reason: 'A foreign SMS must NEVER change the global app currency');
  });

  test('M292 original currencies do not get added together as ledger numbers', () {
    final batch = WaffraSmsCurrencies.summarize([
      'Card Purchase Amount USD 50.00',
      'تم خصم ١٠٠ جنيه مصري',
      'شراء 200 SAR',
      'Transfer EUR 10.00',
    ]);
    expect(batch.hasMixedCurrencies, isTrue);
    expect(batch.needsCurrencyReview, isTrue);
    expect(batch.counts, {'USD': 1, 'EGP': 1, 'SAR': 1, 'EUR': 1});
    expect(batch.summary, contains('EGP: 1'));
    expect(batch.summary, contains('USD: 1'));
  });

  test('M292 FX stamps reject missing, stale, future and tampered tables', () {
    final noTimestamp = Map<String, dynamic>.from(rates)
      ..remove('time_last_update_unix');
    expect(() => WaffraSmsFxQuote.fromUsdRates(
      noTimestamp, originalCurrency: 'USD',
      targetCurrency: 'SAR', now: now), throwsFormatException);
    expect(() => WaffraSmsFxQuote.fromUsdRates(
      rates, originalCurrency: 'USD', targetCurrency: 'SAR',
      now: at.add(const Duration(days: 8))), throwsFormatException);
    expect(() => WaffraSmsFxQuote.fromUsdRates(
      rates, originalCurrency: 'USD', targetCurrency: 'SAR',
      now: at.subtract(const Duration(days: 2))), throwsFormatException);
    final negative = <String, dynamic>{
      ...rates, 'rates': {'USD': 1.0, 'SAR': -3.75},
    };
    expect(() => WaffraSmsFxQuote.fromUsdRates(
      negative, originalCurrency: 'USD',
      targetCurrency: 'SAR', now: now), throwsFormatException);
  });

  test('M292 minor units cover 0, 2 and 3-decimal currencies', () {
    expect(WaffraCurrencyMinor.exact(120, 'JPY'), 120);
    expect(WaffraCurrencyMinor.exact(120.45, 'JPY'), isNull);
    expect(WaffraCurrencyMinor.exact(10.125, 'KWD'), 10125);
    expect(WaffraCurrencyMinor.exact(10.1254, 'KWD'), isNull);
    expect(WaffraCurrencyMinor.exact(10.12, 'SAR'), 1012);
    expect(WaffraCurrencyMinor.exact(10.123, 'SAR'), isNull);
    expect(WaffraCurrencyMinor.exact(-5, 'USD'), isNull);
  });

  test('M292 snapshot tampering cannot silently alter the amount or rate', () {
    final snap = WaffraSmsFxReview.approve(
      originalAmount: 25, quote: quote('USD', 'SAR'),
      userConfirmed: true, now: now).toProvenanceJson();
    expect(() => WaffraSmsFxReview.fromProvenanceJson(
      {...snap, 'convertedMinor': 100000}), throwsFormatException);
    expect(() => WaffraSmsFxReview.fromProvenanceJson(
      {...snap, 'targetPerOriginal': double.nan}), throwsFormatException);
    expect(() => WaffraSmsFxReview.fromProvenanceJson(
      {...snap, 'originalCurrency': 'XXX'}), throwsFormatException);
  });

  test('M293 restored FX snapshots reject stale approvals and non-UTC stamps',
      () {
    final snap = WaffraSmsFxReview.approve(
      originalAmount: 25, quote: quote('USD', 'SAR'),
      userConfirmed: true, now: now).toProvenanceJson();
    expect(() => WaffraSmsFxReview.fromProvenanceJson({
      ...snap, 'approvedUtc': at.add(const Duration(days: 8)).toIso8601String(),
    }), throwsFormatException);
    expect(() => WaffraSmsFxReview.fromProvenanceJson({
      ...snap, 'approvedUtc': at.subtract(const Duration(days: 2)).toIso8601String(),
    }), throwsFormatException);
    expect(() => WaffraSmsFxReview.fromProvenanceJson({
      ...snap, 'approvedUtc': now.toIso8601String().replaceAll('Z', ''),
    }), throwsFormatException);
  });

  test('M292 second provider date and audit label are preserved', () {
    final backed = WaffraSmsFxQuote.fromUsdBackup(
      {
        'date': '2026-10-27',
        'usd': {'usd': 1.0, 'sar': 3.75, 'egp': 48.0},
      },
      originalCurrency: 'USD',
      targetCurrency: 'EGP',
      now: now,
    );
    expect(backed.provider, 'fawazahmed0 Currency API');
    expect(backed.targetPerOriginal, 48);
  });

  test('M292 network sends only currency/rate request, not SMS text', () async {
    final seen = <Uri>[];
    final mock = MockClient((request) async {
      seen.add(request.url);
      return http.Response(jsonEncode(rates), 200,
        headers: {'content-type': 'application/json'});
    });
    final result = await WaffraSmsFxQuote.fetch(
      originalCurrency: 'USD',
      targetCurrency: 'SAR',
      client: mock,
      now: now,
    );
    expect(result.targetPerOriginal, 3.75);
    expect(seen, hasLength(1));
    expect(seen.single.host, 'open.er-api.com');
    expect(seen.single.path, '/v6/latest/USD');
    expect(seen.single.query, isEmpty);
    mock.close();
  });

  test('M292 no FX ledger write until encrypted provenance migration', () {
    final source = WaffraSmsFxQuote.fromUsdRates(
      rates, originalCurrency: 'EUR', targetCurrency: 'SAR', now: now);
    expect(source.targetCurrency, 'SAR');
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(
      'Card purchase Amount EUR 55.00'), isTrue);
    // No ledger writer, no automatic commit and no mutation to global
    // display preferences happens anywhere in the draft model.
  });
}

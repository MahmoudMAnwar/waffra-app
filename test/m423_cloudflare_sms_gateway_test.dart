import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waffra/waffra_cloudflare_sms_gateway.dart';
import 'package:waffra/waffra_sms_cloud_redactor.dart';

void main() {
  const english = 'SAR 75.00 debited at TEST STORE';
  const arabic = 'تم خصم ٧٥.٠٠ ريال من متجر تجريبي';
  const incoming = 'JOD198.000 credited by CliQ transfer';
  final endpoint = Uri.parse(
    'https://waffra-sms-staging.mahmoudmanwar159.workers.dev/analyze');

  Map<String, Object?> result(String quote, {
      String amount = '75.00', String currency = 'SAR',
      String direction = 'expense', String description = 'TEST STORE'}) =>
    <String, Object?>{
      'ok': true, 'unverified': true, 'review_required': true,
      'transactions': <Object?>[
        <String, Object?>{
          'direction': direction, 'amount': amount,
          'currency': currency, 'description': description,
          'source_quote': quote,
        }
      ],
    };

  test('M423: verified English expense remains review-only', () {
    final item = WaffraCloudflareSmsGateway.validateSuggestion(
      english, result(english));
    expect(item?['kind'], 'expense');
    expect(item?['amount'], 75);
    expect(item?['currency'], 'SAR');
    expect(item?['verifiedForPosting'], false);
    expect(item?['requiresReview'], true);
  });

  test('M423: Arabic expense and Arabic-Indic digits are grounded', () {
    final item = WaffraCloudflareSmsGateway.validateSuggestion(
      arabic, result(arabic, amount: '٧٥.٠٠'));
    expect(item?['kind'], 'expense');
    expect(item?['amount'], 75);
    expect(item?['verifiedForPosting'], false);
  });

  test('M423: foreign currency never posts as SAR', () {
    final item = WaffraCloudflareSmsGateway.validateSuggestion(
      incoming, result(incoming, amount: '198.000',
        currency: 'JOD', direction: 'income', description: 'CliQ'));
    expect(item?['currency'], 'JOD');
    expect(item?['amount'], 198);
    expect(item?['requiresReview'], true);
    expect(item?['verifiedForPosting'], false);
  });

  test('M423: mismatched, invented and reordered amount rejected', () {
    for (final amount in ['7500', '76.00', '75.000', '-75', '12345678']) {
      expect(WaffraCloudflareSmsGateway.validateSuggestion(
        english, result(english, amount: amount)), isNull);
    }
  });

  test('M423: mismatched currency is rejected', () {
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      english, result(english, currency: 'AED')), isNull);
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      'تم خصم ٧٥.٠٠ درهم', result('تم خصم ٧٥.٠٠ درهم',
      amount: '٧٥.٠٠', currency: 'SAR')), isNull);
  });

  test('M423: hallucinated quote, multiple transactions rejected', () {
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      english, result('SAR 100.00 debited')), isNull);
    final duplicate = result(english);
    (duplicate['transactions'] as List).add(
      Map<String, Object?>.from((duplicate['transactions'] as List).first as Map));
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      english, duplicate), isNull);
  });

  test('M423: pending, declined and OTP SMS cannot be accepted', () {
    for (final message in [
      'SAR 75.00 debited at TEST STORE pending',
      'SAR 75.00 debited at TEST STORE declined',
      'SAR 75.00 debited at TEST STORE OTP 1234',
    ]) {
      expect(WaffraCloudflareSmsGateway.validateSuggestion(
        message, result(message)), isNull);
      // A response containing pending or OTP must never authorize posting.
    }
  });

  test('M423: conflicting bank direction cannot follow model guess', () {
    final item = WaffraCloudflareSmsGateway.validateSuggestion(
      english, result(english, direction: 'income'));
    expect(item?['kind'], 'uncertain');
    expect(item?['requiresReview'], true);
    expect(item?['verifiedForPosting'], false);
  });

  test('M423: transfer needs review even when model says income', () {
    final source = 'Credit Transfer via Alinma Bank Amount: 1900 SAR';
    final item = WaffraCloudflareSmsGateway.validateSuggestion(
      source, result(source, amount: '1900', direction: 'income'));
    expect(item?['kind'], 'uncertain');
    expect(item?['verifiedForPosting'], false);
  });

  test('M423: missing review flag and malformed schema rejected', () {
    final missingFlag = result(english)..remove('review_required');
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      english, missingFlag), isNull);
    final noRows = result(english)..['transactions'] = [];
    expect(WaffraCloudflareSmsGateway.validateSuggestion(
      english, noRows), isNull);
  });

  test('M423: reject arbitrary hosts, plaintext and query strings', () {
    for (final value in [
      'http://waffra-sms-staging.example.com/analyze',
      'https://evil.example.com/analyze',
      'https://waffra-sms-staging.workers.dev/analyze?token=bad',
      'https://waffra-sms-staging.workers.dev/other',
    ]) {
      expect(WaffraCloudflareSmsGateway.validEndpoint(value), isNull);
    }
    expect(WaffraCloudflareSmsGateway.validEndpoint(
      endpoint.toString()), isNotNull);
  });

  test('M423: authenticated transport sends only redacted SMS and consent',
      () async {
    var called = 0;
    final client = MockClient((request) async {
      called++;
      expect(request.method, 'POST');
      expect(request.url, endpoint);
      expect(request.headers['authorization'], 'Bearer test.signed.token');
      final body = jsonDecode(request.body) as Map;
      expect(body['cloudConsent'], true);
      expect(body['text'], english);
      expect(request.body.contains('OPENROUTER_API_KEY'), false);
      return http.Response(jsonEncode(result(english)), 200);
    });
    final item = await WaffraCloudflareSmsGateway.analyze(
      source: english, firebaseIdToken: 'test.signed.token',
      endpoint: endpoint, client: client);
    expect(called, 1);
    expect(item?['requiresReview'], true);
    expect(item?['verifiedForPosting'], false);
    client.close();
  });

  test('M423: OTP, missing token and provider failure all fall back', () async {
    var called = 0;
    final client = MockClient((request) async {
      called++;
      return http.Response('{"error":"provider_error"}', 502);
    });
    expect(await WaffraCloudflareSmsGateway.analyze(
      source: english, firebaseIdToken: '',
      endpoint: endpoint, client: client), isNull);
    expect(await WaffraCloudflareSmsGateway.analyze(
      source: 'OTP 1234 for SAR 75.00 payment',
      firebaseIdToken: 'test.signed.token',
      endpoint: endpoint, client: client), isNull);
    expect(called, 0);
    expect(await WaffraCloudflareSmsGateway.analyze(
      source: english, firebaseIdToken: 'test.signed.token',
      endpoint: endpoint, client: client), isNull);
    expect(called, 1);
    client.close();
  });
}

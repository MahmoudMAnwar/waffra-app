import 'dart:convert';
import 'package:http/http.dart' as http;

import 'waffra_ai_finance_brain.dart';
import 'waffra_bank_sms_facts.dart';
import 'waffra_sms_cloud_redactor.dart';

/// M423: Cloudflare Worker transport for consented, redacted bank-SMS review.
///
/// URL is a public build setting; ONLY a short-lived, signed Firebase ID token
/// is sent as Authorization. Never embed a Worker staging token or OpenRouter
/// API key in Flutter. A staging Worker accepting only WAFFRA_STAGING_TOKEN
/// will return 401 until it is upgraded to verify signed identity tokens.
///
/// Nothing here can persist a transaction. Every result requires user review.
abstract final class WaffraCloudflareSmsGateway {
  static const configuredUrl = String.fromEnvironment(
    'WAFFRA_SMS_WORKER_URL', defaultValue: '',
  );
  static bool get configured => configuredUrl.isNotEmpty;

  static Uri? validEndpoint(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        uri.path != '/analyze') return null;
    // A non-Cloudflare custom domain requires independent allowlist review.
    if (!uri.host.endsWith('.workers.dev')) return null;
    return uri;
  }

  /// Validates every important model claim against the *redacted* source.
  /// Wrong counts, invented amounts, conflicting status, unexpected schemas,
  /// currencies or direction never grant finance-writer authority.
  static Map<String, Object?>? validateSuggestion(
      String redactedSource, Object? response) {
    if (response is! Map || response['ok'] != true ||
        response['unverified'] != true ||
        response['review_required'] != true) return null;
    final rows = response['transactions'];
    // A single SMS must resolve to exactly one action or fall back locally.
    if (rows is! List || rows.length != 1 || rows.single is! Map) {
      return null;
    }
    final row = rows.single as Map;
    final quote = row['source_quote'];
    final rawAmount = row['amount'];
    final rawCurrency = row['currency'];
    final direction = row['direction'];
    final description = row['description'];
    if (quote is! String || quote.isEmpty || quote.length > 500 ||
        !redactedSource.contains(quote) ||
        rawAmount is! String || rawAmount.isEmpty ||
        rawCurrency is! String || rawCurrency.isEmpty ||
        direction is! String || !{'income', 'expense'}.contains(direction) ||
        description is! String || description.length > 90 ||
        WaffraAiFinanceBrain.unconfirmed(redactedSource) ||
        WaffraAiFinanceBrain.competingAmounts(quote) ||
        !WaffraAiFinanceBrain.exactCurrency(quote, rawCurrency)) {
      return null;
    }

    final money = WaffraAiFinanceBrain.digits(rawAmount);
    final moneyPattern = RegExp(
      r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,3})?$',
    );
    if (!moneyPattern.hasMatch(money) ||
        !RegExp(r'(?<![0-9])' + RegExp.escape(money) + r'(?![0-9])')
            .hasMatch(WaffraAiFinanceBrain.digits(quote))) return null;
    final amount = double.tryParse(money.replaceAll(',', ''));
    final currency = WaffraAiFinanceBrain.currencyCode(rawCurrency);
    if (amount == null || !amount.isFinite || amount <= 0 ||
        amount > 100000000 || currency == null) return null;
    if (currency == 'SAR' &&
        !RegExp(r'^\d+(?:\.\d{1,2})?$')
            .hasMatch(money.replaceAll(',', ''))) return null;

    final facts = WaffraBankSmsFactsParser.parse(redactedSource);
    if (facts.pending) return null;
    final matched = (direction == 'income' &&
                       facts.kind == WaffraBankOperationKind.income) ||
                    (direction == 'expense' &&
                       facts.kind == WaffraBankOperationKind.expense);
    // Transfers, settlements and conflicting local classification never
    // inherit the model's direction. A mismatch is an unsafe suggestion.
    return <String, Object?>{
      'kind': matched ? direction : 'uncertain',
      'amount': amount,
      'currency': currency,
      'merchant': description.isEmpty ? null : description,
      'fee': null,
      'requiresReview': true,
      'verifiedForPosting': false,
    };
  }

  static Future<Map<String, Object?>?> analyze({
    required String source,
    required String firebaseIdToken,
    required Uri endpoint,
    http.Client? client,
  }) async {
    if (validEndpoint(endpoint.toString()) == null ||
        firebaseIdToken.isEmpty) return null;
    final redacted = WaffraSmsCloudRedactor.redact(source);
    if (redacted == null) return null;
    final owned = client == null;
    final transport = client ?? http.Client();
    try {
      final result = await transport.post(
        endpoint,
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer $firebaseIdToken',
        },
        body: jsonEncode(<String, Object>{
          'cloudConsent': true,
          'text': redacted,
        }),
      ).timeout(const Duration(seconds: 18));
      if (result.statusCode != 200 || result.body.length > 16000) return null;
      return validateSuggestion(redacted, jsonDecode(result.body));
    } catch (_) {
      // Never log bank SMS, tokens, model output or provider errors.
      return null;
    } finally {
      if (owned) transport.close();
    }
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ai_finance_brain.dart';
import 'package:waffra/waffra_auto_sms_policy.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_cloudflare_sms_gateway.dart';
import 'package:waffra/waffra_sms_cloud_redactor.dart';

void main() {
  test('M470 all Dart sources avoid ambiguous bare Arabic رس currency', () {
    final sources = Directory('lib').listSync(recursive: true)
        .whereType<File>().where((file) => file.path.endsWith('.dart')).toList();
    expect(sources.length, greaterThan(100));
    for (final file in sources) {
      final raw = file.readAsStringSync();
      expect(raw.contains(r'ر\.?\s*س'), isFalse,
          reason: 'Unsafe currency abbreviation in ${file.path}');
      expect(raw.contains('\uFFFD'), isFalse,
          reason: 'Replacement character in ${file.path}');
    }
  });

  test('M470 Arabic message counts do not become SAR currency evidence', () {
    const text = 'تم إيداع 500 رسالة بنكية';
    final decision = WaffraAutoSmsPolicy.decide(
      sender: 'AlinmaPay',
      sms: text,
      parsedAmount: 500,
      parsedIncome: true,
      foreignCurrency: false,
      arrived: DateTime(2026, 11, 5),
      sourceAccountVerified: true,
    );
    expect(decision.canPost, isFalse);
    expect(decision.reason, 'currency_not_verified');
  });

  test('M470 authentic SAR units remain valid for strict SMS gating', () {
    final decision = WaffraAutoSmsPolicy.decide(
      sender: 'AlinmaPay',
      sms: 'تم إيداع مبلغ 135.00 SAR',
      parsedAmount: 135,
      parsedIncome: true,
      foreignCurrency: false,
      arrived: DateTime(2026, 11, 5),
      sourceAccountVerified: true,
    );
    expect(decision.canPost, isTrue);
  });

  test('M470 currency-less OCR caption cannot create a financial amount', () {
    final rows = WaffraBankScreenshotParser.reviewItems(
      'تم إيداع 500 رسالة بانتظار المراجعة',
    );
    expect(rows, hasLength(1));
    expect(rows.single.amount, isNull);
    final sar = WaffraBankScreenshotParser.reviewItems(
      'تم إيداع 135.00 SAR',
    );
    expect(sar, hasLength(1));
    expect(sar.single.amount, 135);
  });

  test('M470 currency-less Arabic prose cannot authorize cloud analysis', () {
    const text = 'حوالة واردة 500 رسالة من AlinmaPay بانتظار المراجعة';
    expect(WaffraSmsCloudRedactor.redact(text), isNull);
    expect(WaffraCloudflareSmsGateway.sourceCurrencyMatches(text, 'SAR'),
        isFalse);
    expect(WaffraAiFinanceBrain.competingAmounts(
        '500 رسالة بنكية و 250 رسالة أخرى'), isFalse);
  });

  test('M470 real Riyal amount is still allowed in redacted preview', () {
    const text = 'حوالة واردة بقيمة 135.00 SAR عبر AlinmaPay';
    expect(WaffraSmsCloudRedactor.redact(text), isNotNull);
    expect(WaffraCloudflareSmsGateway.sourceCurrencyMatches(
        'حوالة واردة بقيمة 135 ريال سعودي', 'SAR'), isTrue);
  });
}

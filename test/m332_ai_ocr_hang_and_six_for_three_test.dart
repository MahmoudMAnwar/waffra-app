import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ai_finance_brain.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';

void main() {
  const threeBankMessages =
      'شراء POS SAR 10.00\nمتجر أول\n'
      'شراء POS SAR 20.00\nمتجر ثان\n'
      'شراء POS SAR 30.00\nمتجر ثالث';

  Map<String, Object?> row(String quote, String amount) => {
    'source_quote': quote,
    'amount_text': amount,
    'currency_text': 'SAR',
    'direction': 'expense',
    'merchant': null,
  };

  test('M332: one purchase with purchase+POS is never counted twice', () {
    final result = WaffraBankScreenshotParser.reviewItems(threeBankMessages);
    expect(result.length, 3);
    expect(result.map((x) => x.amount).toList(), [10.0, 20.0, 30.0]);
    expect(result.every((x) => !x.income), true);
  });

  test('M332: stacked action synonyms without amount are one payment', () {
    const raw = 'شراء\nPOS\nSAR 10.00\n'
      'حوالة واردة\nReceived\nSAR 25.00';
    final result = WaffraBankScreenshotParser.reviewItems(raw);
    expect(result.length, 2);
    expect(result[0].amount, 10);
    expect(result[1].amount, 25);
    expect(result[1].income, true);
  });

  test('M332: six model rows for three source transactions are rejected', () async {
    final six = [
      row('شراء POS SAR 10.00', '10.00'),
      row('POS SAR 10.00', '10.00'),
      row('شراء POS SAR 20.00', '20.00'),
      row('POS SAR 20.00', '20.00'),
      row('شراء POS SAR 30.00', '30.00'),
      row('POS SAR 30.00', '30.00'),
    ];
    final result = await WaffraAiFinanceBrain.imageOcr(
      threeBankMessages,
      generate: (_) async => jsonEncode({'transactions': six}),
    );
    expect(result.count, 0);
    expect(result.error, 'untrusted_model_output');
  });

  test('M332: three correctly grounded rows remain readable', () async {
    final result = await WaffraAiFinanceBrain.imageOcr(
      threeBankMessages,
      generate: (_) async => jsonEncode({
        'transactions': [
          row('شراء POS SAR 10.00', '10.00'),
          row('شراء POS SAR 20.00', '20.00'),
          row('شراء POS SAR 30.00', '30.00'),
        ],
      }),
    );
    expect(result.error, isNull);
    expect(result.count, 3);
    expect(result.needsReviewCount, 0);
  });

  test('M636 generic OCR progress can cancel without any Qwen model',(){
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains("Key('waffra-ai-analysis-cancel')"));
    expect(app,contains('Future.any<T>([work,cancellation.future])'));
    expect(app,contains('item.remove();'));
    expect(app,contains('item.dispose();'));
    expect(app,isNot(contains('WaffraOnDeviceQwen')));
  });
  test('M636 bank SMS human confirmation remains mandatory',(){
    final app=File('lib/main.dart').readAsStringSync();
    expect(app,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
    expect(app,contains('if(smsHashes.contains(bankSmsHash(body)))'));
    expect(app,isNot(contains('Future<void> bulkSmsSheet(')));
  });
}

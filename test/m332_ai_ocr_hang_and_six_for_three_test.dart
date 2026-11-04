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

  test('M332: AI overlay can cancel and never blocks app forever', () {
    final app = File('lib/main.dart').readAsStringSync();
    final engine = File('lib/waffra_ondevice_qwen.dart').readAsStringSync();
    expect(app, contains("Key('waffra-ai-analysis-cancel')"));
    expect(app, contains('waffra_ai_analysis_timeout'));
    expect(app, contains('Future.any<T>([work,cancellation.future])'));
    expect(app, contains('cancelCurrentGeneration()'));
    expect(engine, contains('generationTimeLimit=Duration(seconds:45)'));
    expect(engine, contains('engine.create(['));
    expect(engine, contains('maxTokens:768'));
    expect(engine, contains('/no_think'));
    expect(engine, contains('cancelGeneration()'));
    expect(app, contains('WaffraAiResult result;'));
    expect(app, contains('AI timed out. Review the extracted image transactions manually.'));
    expect(app, contains("error.message!='ai_analysis_cancelled'"));
    expect(app, contains('return false;'));
  });

  test('M332: SMS paste/share auto-runs AI; button removed; no AI save', () {
    final app = File('lib/main.dart').readAsStringSync();
    expect(app, contains('scheduleBankSmsAnalysis(ctx,update,text)'));
    expect(app, contains('analyzeBankSmsAutomatically(ctx,update,input.trim(),revision)'));
    expect(app, contains('await _reviewAiPastedBankMessages(ctx,input)'));
    expect(app, contains('جاري الآن تحليل الرسائل بالذكاء الاصطناعي'));
    expect(app, isNot(contains("Key('waffra-sms-ai-review')")));
    expect(app, contains('waffra-sms-review-unverified'));
    expect(app, contains('Never commit on paste'));
    expect(app, contains('userConfirmed:true'));
    // Unexpected native errors must not strand the paste progress state.
    expect(app, contains('AI analysis was interrupted. Review bank messages manually.'));
    expect(app, contains('analyzingPaste=false;'));
    expect(app, contains('Review before saving.'));
    // Re-paste/clear/close invalidates stale AI results and native inference.
    expect(app, contains('scheduleBankSmsAnalysis('));
    expect(app, contains('++pasteRevision;pasted.clear();'));
    expect(app, contains('++pasteRevision;'));
    expect(app, contains('WaffraOnDeviceQwen.shared.cancelCurrentGeneration();'));
    expect(app, contains('analyzingPaste=false;messages=[];index=0;pasted.clear()'));
  });
}

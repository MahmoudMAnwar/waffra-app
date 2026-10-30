import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
  test('M320 opt-in AI is wired to all five features with manual finance review',(){
    final home=File('lib/main.dart').readAsStringSync();
    final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
    final runner=File('lib/waffra_ondevice_qwen.dart').readAsStringSync();
    expect(home,contains('await _reviewAiScannedTransactions('));
    expect(home,contains('WaffraAiFinanceBrain.imageOcr('));
    expect(home,contains('waffra-sms-ai-review'));
    expect(home,contains('WaffraAiFinanceBrain.bankSms('));
    expect(home,contains('result.items[i].needsReview?null:'));
    expect(home,contains('item.currency!='));
    expect(home,contains('await entrySheet('));
    expect(tools,contains('waffra-local-ai-opt-in'));
    expect(tools,contains('waffra-ai-financial-analysis'));
    expect(tools,contains('waffra-ai-saving-suggestions'));
    expect(tools,contains('WaffraAiFinanceCoach.askWaffra('));
    expect(tools,contains('WaffraAiFinanceCoach.analysis('));
    expect(tools,contains('WaffraAiFinanceCoach.savingSuggestions('));
    expect(tools,contains('WaffraAiModelGate.ensureReady('));
    expect(home,contains('WaffraAiModelGate.ensureReady('));
    expect(home,contains('await WaffraOnDeviceQwen.shared.dispose()'));
    expect(runner,contains('account_session_changed'));
    expect(runner,contains('_activeDownload?.close()'));
  });

  test('M320 bank SMS and OCR remain unaffected when AI is not enabled',(){
    final home=File('lib/main.dart').readAsStringSync();
    final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(home,contains('if(!WaffraOnDeviceQwen.shared.isReady)return false;'));
    expect(home,contains('if(!WaffraOnDeviceQwen.shared.isReady||source.trim().isEmpty)return;'));
    expect(home,contains('final candidates=WaffraBankScreenshotParser.candidates(extracted.rawText);'));
    expect(home,contains('if(statusMessage.isEmpty&&messages.isNotEmpty)saveParsedMessages(ctx,update);'));
    expect(tools,contains('if(q.isNotEmpty&&WaffraOnDeviceQwen.shared.isReady)'));
    expect(tools,contains("if(q.isEmpty){setState(()=>answer="));
  });
}

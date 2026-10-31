import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gate = File('lib/waffra_ai_model_gate.dart').readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();
  final engine = File('lib/waffra_ondevice_qwen.dart').readAsStringSync();

  test('M329 verified model is reactivated instead of offered a second download', () {
    expect(gate, contains('final installed=await model.installedAndVerified();'));
    expect(gate, contains('final agreed=installed?true:await showDialog<bool>'));
    expect(gate, contains('await model.open(allowDownload:!installed,'));
    expect(engine, contains('getApplicationSupportDirectory()'));
    expect(engine, contains("final dir=Directory(folder.path+'/waffra_public_ai_models');"));
    expect(engine, contains('if(!await _verified(file)){'));
  });

  test('M329 camera/gallery OCR shows work progress and always removes overlay', () {
    expect(main, contains("Key('waffra-ai-analysis-progress')"));
    expect(main, contains('item.remove();'));
    expect(main, contains('item.dispose();'));
    expect(main, contains('completed=true;\n   item.remove();'));
    expect(main, contains('()=>WaffraReceiptOcr.scan(picked.path)'));
    expect(main, contains('()=>WaffraAiFinanceBrain.imageOcr(sourceText,'));
    expect(main, contains('WaffraBankScreenshotParser.reviewItems(extracted.rawText)'));
  });

  test('M329 bank SMS AI review displays progress and keeps manual confirmation', () {
    expect(main, contains('()=>WaffraAiFinanceBrain.bankSms(source,'));
    expect(main, isNot(contains('waffra-sms-ai-review')));
    expect(main, contains('تحليل الرسائل بالذكاء الاصطناعي'));
    expect(main, contains('if(!WaffraOnDeviceQwen.shared.isReady)return false;'));
    expect(main, contains('await entrySheet('));
    expect(main, contains('if(!allowed||!mounted||_smsSheetOpen)return;'));
  });
}

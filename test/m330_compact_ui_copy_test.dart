import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M636 AI model download UI is entirely retired',(){
    final main=File('lib/main.dart').readAsStringSync();
    final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(File('lib/waffra_ai_model_gate.dart').existsSync(),isFalse);
    expect(File('lib/waffra_ondevice_qwen.dart').existsSync(),isFalse);
    expect(main,isNot(contains('deleteAiModel()')));
    expect(tools,isNot(contains('waffra-ai-tools-install-section')));
    expect(tools,isNot(contains('waffra-local-ai-opt-in')));
  });

  test('M640 retired scanner is absent while finance tools remain',(){
    final home=File('lib/main.dart').readAsStringSync();
    final country=File('lib/waffra_country_first_run_page.dart').readAsStringSync();
    final receipt=File('lib/waffra_practical_tools_page.dart').readAsStringSync();
    final smart=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(home,isNot(contains('WaffraReceiptOcr.scan(')));
    expect(home,isNot(contains('waffra-ocr-analysis-progress')));
    expect(country,contains('لا نحفظ موقعك ولا نتتبعك.'));
    expect(receipt,isNot(contains('receiptAssistant()')));
    expect(receipt,contains("section(2, 'الإقفال الشهري'"));
    expect(smart,contains('أدوات وفرة الذكية'));
    expect(smart,isNot(contains('تنزيل نموذج الذكاء')));
  });

  test('M330 shared translations preserve keys while shortening visible output',(){
    final source=File('lib/waffra_i18n.dart').readAsStringSync();
    expect(source,contains('_compactUiCopy'));
    expect(source,contains('compact?.ar??source'));
    expect(source,contains('if(compact!=null)return compact.en;'));
    expect(source,contains('الاستعادة تستبدل المعاملات'));
  });
}

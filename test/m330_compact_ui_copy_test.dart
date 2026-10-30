import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M330 AI consent is short and cannot show a second warning on decline',(){
    final source=File('lib/waffra_ai_model_gate.dart').readAsStringSync();
    expect(source,contains("'تنزيل نموذج الذكاء'"));
    expect(source,contains("'Download AI model'"));
    expect(source,contains("english?'Later':'لاحقًا'"));
    expect(source,contains("english?'Download now':'تنزيل الآن'"));
    expect(source,contains("الإضافة اليدوية متاحة"));
    expect(source,isNot(contains('waffra-ai-required-feature-notice')));
    expect(source,isNot(contains('نموذج الذكاء الاصطناعي في وفرة')));
    expect(source,isNot(contains('تجهيز ذكاء وفرة الاصطناعي')));
  });

  test('M330 download bar keeps percentage and MB readable in RTL',(){
    final source=File('lib/waffra_ai_model_gate.dart').readAsStringSync();
    expect(source,contains('waffra-ai-model-download-progress'));
    expect(source,contains('Directionality(textDirection:TextDirection.ltr'));
    expect(source,contains("(received/1048576).toStringAsFixed(1)"));
    expect(source,contains("(total!/1048576).toStringAsFixed(1)+' MB'"));
    expect(source,isNot(contains('Deleting it disables AI analysis only; your')));
  });

  test('M330 core screens have concise Arabic and English messages',(){
    final home=File('lib/main.dart').readAsStringSync();
    final country=File('lib/waffra_country_first_run_page.dart').readAsStringSync();
    final receipt=File('lib/waffra_practical_tools_page.dart').readAsStringSync();
    final smart=File('lib/waffra_smart_features.dart').readAsStringSync();
    expect(home,contains('راجع العمليات بالترتيب.'));
    expect(home,isNot(contains('Detected $label in the bank image. This amount cannot be added as SAR')));
    expect(country,contains('لا نحفظ موقعك ولا نتتبعك.'));
    expect(country,contains("We don't save or track your location."));
    expect(receipt,contains('اختر فاتورة أو صوّرها.'));
    expect(smart,contains('حمّل النموذج لتفعيل أدوات الذكاء.'));
  });

  test('M330 shared translations preserve keys while shortening visible output',(){
    final source=File('lib/waffra_i18n.dart').readAsStringSync();
    expect(source,contains('_compactUiCopy'));
    expect(source,contains('compact?.ar??source'));
    expect(source,contains('if(compact!=null)return compact.en;'));
    expect(source,contains('الاستعادة تستبدل المعاملات'));
  });
}

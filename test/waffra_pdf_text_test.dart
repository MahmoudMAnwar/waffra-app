import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_pdf_text.dart';

void main() {
  test('old and new Saudi rial symbols are readable in Tajawal PDFs', () {
    const sms = 'شراء PoS \uFDFC 74 \u20C1 SAR 74\uE900 21:59\uFFFD';
    final result = sanitizeWaffraPdfText(sms);
    expect(result, contains('شراء PoS'));
    expect(result, contains('ريال 74 ريال'));
    expect(result, contains('SAR 74'));
    expect(result, contains('21:59'));
    expect(result.contains('\uFDFC'), isFalse);
    expect(result.contains('\u20C1'), isFalse);
    expect(result.contains('\uE900'), isFalse);
    expect(result.contains('\uFFFD'), isFalse);
  });

  test('Arabic and English bank SMS parts have separate text directions', () {
    const sms = 'شراء نقاط بيع - شراء PoS عبر:7678 مدى-مدى SAR 74 Petro 288 7/10/26 21:59';
    final runs = splitWaffraPdfText(sms);
    expect(runs.length, greaterThanOrEqualTo(3));
    expect(runs.first.rtl, isTrue);
    expect(runs.any((e) => !e.rtl && e.text.contains('PoS')), isTrue);
    expect(runs.any((e) => !e.rtl && e.text.contains('21:59')), isTrue);
    expect(runs.any((e) => e.rtl && e.text.contains('مدى')), isTrue);
  });

  test('leaves readable Arabic names, category text and amounts intact', () {
    expect(sanitizeWaffraPdfText('حوالة واردة من عبدالله 9288 SAR 15.50'),
        'حوالة واردة من عبدالله 9288 SAR 15.50');
    expect(splitWaffraPdfText('').single.text, 'لا يوجد وصف');
    expect(sanitizeWaffraPdfText('١٬٥٠٠٫٥٠'), '١,٥٠٠.٥٠');
  });
}

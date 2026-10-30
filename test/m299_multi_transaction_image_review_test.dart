import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';

void main() {
  test('M299 numbered entries retain every recognized bank action', () {
    const source = '''
AlRajhiBank
شراء POS
عبر:7678-مدى
SAR 33.00
Corner Market
29/10/26
شراء POS
SAR 4.00
Coffee Shop
29/10/26
تحويل وارد
SAR 620.50
29/10/26
شراء POS
SAR 10.00
SAR 15.00
29/10/26
شراء POS
SAR 9.25
Supermarket
29/10/26
''';
    final rows = WaffraBankScreenshotParser.reviewItems(source);
    expect(rows.length, 5);
    expect(rows.map((e) => e.position), [1, 2, 3, 4, 5]);
    expect(rows.map((e) => e.amount), [33, 4, 620.5, null, 9.25]);
    expect(rows.map((e) => e.income), [false, false, true, false, false]);
    expect(rows[3].needsAmountReview, isTrue);
    expect(rows[3].sourceText, contains('SAR 15.00'));
    expect(WaffraBankScreenshotParser.candidates(source).length, 4);
  });

  test('M299 repeated actions on same OCR line become separate review rows', () {
    final rows = WaffraBankScreenshotParser.reviewItems(
      'شراء POS SAR 33.00 متجر شراء POS SAR 4.50 مقهى',
    );
    expect(rows.length, 2);
    expect(rows.map((e) => e.amount), [33, 4.5]);
    expect(rows.map((e) => e.position), [1, 2]);
    expect(rows[1].sourceLine, greaterThan(rows[0].sourceLine));
  });

  test('M299 localized SAR amounts are read safely', () {
    final rows = WaffraBankScreenshotParser.reviewItems(
      'شراء POS\n١٬٢٣٤٫٥٠ ريال\nمتجر\n30/10/26\n'
      'تحويل وارد\nSAR 9,999.99\n30/10/26',
    );
    expect(rows.length, 2);
    expect(rows[0].amount, 1234.50);
    expect(rows[1].amount, 9999.99);
    expect(rows[1].income, isTrue);
  });

  test('M299 never pre-fills card/balance or competing amounts', () {
    final rows = WaffraBankScreenshotParser.reviewItems(
      'شراء POS\nالرصيد SAR 500.00\nرقم البطاقة 54077678\n'
      'SAR 2.00\nSAR 3.00\n29/10/26',
    );
    expect(rows.length, 1);
    expect(rows.single.amount, isNull);
    expect(WaffraBankScreenshotParser.candidates(rows.single.sourceText),
        isEmpty);
  });

  test('M299 image review shows detected count, ordinal and explicit save', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('WaffraBankScreenshotParser.reviewItems('));
    expect(main, contains('scannedImagePosition:one.position'));
    expect(main, contains('scannedImagePosition:candidate.position'));
    expect(main, contains('scannedImageTotal:candidates.length'));
    expect(main, contains(r'العملية $scannedImagePosition من $scannedImageTotal في الصورة'));
    expect(main, contains('المبلغ غير واضح'));
    expect(main, contains('entrySheet('));
    expect(main, contains('تأكيد وحفظ العملية'));
  });

  test('M299 local OCR retries sparse text without uploading image', () {
    final source = File('lib/waffra_receipt_ocr.dart').readAsStringSync();
    expect(source, contains("['11', '6']"));
    expect(source, contains("language: 'ara+eng'"));
    expect(source, contains('WaffraBankScreenshotParser.reviewItems('));
    expect(source, isNot(contains('uploadImage(')));
  });
}

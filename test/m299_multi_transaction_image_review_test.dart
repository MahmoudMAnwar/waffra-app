import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

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

  test('M299 all 36 bank currencies are blocked before SAR-only save', () {
    expect(WaffraSmsCurrencies.supported.length,36);
    for(final currency in WaffraSmsCurrencies.supported) {
      final text=currency+'198.50 has been credited to an account. '+
          'Balance 201.50'+currency;
      final foreign=currency!='SAR';
      expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(text),
          foreign,reason:currency);
      expect(WaffraBankScreenshotParser.looksLikeBankScreenshot(text),
          isTrue,reason:currency);
      final actions=WaffraBankScreenshotParser.reviewItems(text);
      expect(actions.length,1,reason:currency);
      expect(actions.single.income,isTrue,reason:currency);
      if(foreign) {
        expect(actions.single.amount,isNull,reason:
          'No FX-provenance foreign amount can be prefixed as SAR: '+currency);
      }
    }
  });

  test('M311 SAR with same-line balance and bank prose stays SAR', () {
    const local='SAR198.50 has been credited to an account. Balance 201.50SAR';
    expect(WaffraSmsCurrencies.currenciesForMessage(local), {'SAR'});
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(local),
      isFalse);
    const foreign='JOD198.125 has been credited to an account. '
      'Balance 201.632JOD';
    expect(WaffraSmsCurrencies.currenciesForMessage(foreign), {'JOD'});
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(foreign),
      isTrue);
    expect(WaffraBankScreenshotParser.reviewItems(foreign).single.amount,
      isNull);
  });

  test('M313 OCR must reject full Arabic foreign-currency names', () {
    for(final pair in <(String,String)>[
      ('ريال قطري','QAR'),
      ('دينار أردني','JOD'),
      ('جنيه إسترليني','GBP'),
      ('درهم مغربي','MAD'),
      ('دولار أمريكي','USD'),
    ]) {
      final raw='حوالة واردة 100 '+pair.$1+' الرصيد 999 ريال';
      expect(WaffraSmsCurrencies.currenciesForMessage(raw),{pair.$2});
      expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(raw),
        isTrue, reason:pair.$1);
    }
  });

  test('M314 unsupported Arabic foreign OCR label never becomes SAR',(){
    const message='حوالة واردة 100 ريال يمني الرصيد 900 ريال';
    expect(WaffraSmsCurrencies.currenciesForMessage(message),
      contains('UNKNOWN'));
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(message),
      isTrue);
  });

  test('M299 finance editor guards every direct OCR caller', () {
    final app=File('lib/main.dart').readAsStringSync();
    final start=app.indexOf('Future<void> entrySheet(');
    final end=app.indexOf('final title=',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final gate=app.substring(start,end);
    expect(gate,contains('WaffraBankScreenshotParser.requiresForeignCurrencyReview('));
    expect(gate,contains('await _canReviewOcrAsLedgerTransaction('));
    expect(gate,contains('return;'));
  });

  test('M299 foreign currency OCR stays numbered but not SAR-prefilled', () {
    for (final currency in ['JOD','USD','EGP','KWD','JPY','EUR']) {
      final imageText=currency+'198.000 has been credited to an account. '
          'Balance 201.632'+currency;
      expect(WaffraBankScreenshotParser.looksLikeBankScreenshot(imageText),
          isTrue,reason:currency);
      final rows=WaffraBankScreenshotParser.reviewItems(imageText);
      expect(rows.length,1,reason:currency);
      expect(rows.single.position,1,reason:currency);
      expect(rows.single.income,isTrue,reason:currency);
      expect(rows.single.amount,isNull,
          reason:'Foreign OCR must not be saved as unconverted SAR: '+currency);
      expect(rows.single.sourceText,contains(currency));
    }
  });

  test('M299 mixed foreign/SAR entries cannot prefill the balance', () {
    final rows=WaffraBankScreenshotParser.reviewItems(
      'شراء POS\nUSD25.50\nBalance SAR 100.00\n'
      'شراء POS\nSAR 3.00\n30/10/26',
    );
    expect(rows.length,2);
    expect(rows[0].amount,isNull);
    expect(rows[1].amount,3);
    expect(rows[0].position,1);
    expect(rows[1].position,2);
  });

  test('M299 SAR-only bank OCR stays eligible for explicit entry review',(){
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(
      'شراء POS SAR 22.50\nمتجر تجريبي'),isFalse);
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(
      'Incoming Transfer credited JOD198.125 Balance 201.632 JOD'),isTrue);
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(
      'Incoming transfer USD 19.50 Balance SAR 999'),isTrue);
    expect(WaffraBankScreenshotParser.requiresForeignCurrencyReview(
      'تحويل وارد EGP 100.00'),isTrue);
  });

  test('M299 all scanner entry routes use foreign-currency fail-closed guard',(){
    final main=File('lib/main.dart').readAsStringSync();
    final start=main.indexOf('Future<void> scanAndAddReceipt()');
    final end=main.indexOf('Future<void> entrySheet(',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final scanner=main.substring(start,end);
    expect(scanner,contains('if(!await _canReviewOcrAsLedgerTransaction(extracted.rawText))return;'));
    expect(scanner,contains('if(!await _canReviewOcrAsLedgerTransaction(one.sourceText))return;'));
    expect(scanner,contains('if(!await _canReviewOcrAsLedgerTransaction(candidate.sourceText))continue;'));
    expect(main,contains('لا يمكن حفظ هذا المبلغ باعتباره ريالًا سعوديًا بدون تحويل موثوق'));
  });

  test('M299 local OCR retries sparse text without uploading image', () {
    final source = File('lib/waffra_receipt_ocr.dart').readAsStringSync();
    expect(source, contains("['11', '6']"));
    expect(source, contains("language: 'ara+eng'"));
    expect(source, contains('WaffraBankScreenshotParser.reviewItems('));
    expect(source, isNot(contains('uploadImage(')));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main() {
  test('extracts a Latin merchant from Saudi POS SMS', () {
    expect(waffraMerchantKey('شراء PoS من مدى SAR 65.90 Shawerma HJ 8/10/26'),
        'shawerma hj');
    expect(waffraMerchantKey('شراء PoS من مدى PANDA RETJ SAR 25.69'),
        'panda retj');
  });

  test('no merchant rules are invented for generic transfers', () {
    expect(waffraMerchantKey('حوالة واردة من 9288 مبلغ 15.50 ريال'), isNull);
  });

  test('rule keys are case-insensitive', () {
    expect(waffraMerchantKey('شراء SR 80.00 PETRO 288'),
        waffraMerchantKey('شراء sr 80.00 petro 288'));
  });
  test('M158: Widget SMS title contains only a generic operation and safe merchant', () {
    const sms='شراء نقاط بيع\nلدى: ALHUSSAIN SHOP\n'
      'البطاقة: ****9876\nالمبلغ: 84.72 SAR';
    final title=waffraSafeSmsTransactionTitle('شراء نقاط بيع',sms,income:false);
    expect(title,'شراء نقاط بيع — ALHUSSAIN SHOP');
    expect(title.contains('9876'),false);
    expect(title.contains('84.72'),false);
    expect(title.contains('البطاقة'),false);
  });

  test('M158: mixed merchant and card/account number is omitted entirely', () {
    const sms='شراء نقاط بيع\nلدى: SHOP 4321123412349999\n'
      'بمبلغ 10 SAR';
    expect(waffraSafeSmsTransactionTitle('شراء نقاط بيع',sms,income:false),
      'شراء نقاط بيع');
    expect(waffraMerchantKey(sms,income:false),isNull);
  });

  test('M158: unknown parser labels cannot echo raw account data', () {
    expect(waffraSafeSmsTransactionTitle(
      'Credit card 5432123454329999','عملية مجهولة',income:true),
      'مبلغ وارد');
  });
}

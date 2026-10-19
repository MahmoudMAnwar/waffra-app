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
}

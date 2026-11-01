import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main() {
  test('M341 English debit account suffix never becomes merchant', () {
    const raw = '136.00 AED debited from account ending with 1001 at '
        'TEST RESTAURAN ABU DHABI AE. Balance: 4857.96 AED';
    final merchant = waffraMerchantName(raw);
    expect(merchant, 'TEST RESTAURAN ABU DHABI AE');
    expect(waffraRecognizedMerchantLeaf(merchant!, income: false),
        'مطاعم وكافيهات / مطاعم شعبية');
    expect(merchant.contains('1001'), isFalse);
    expect(merchant.contains('4857'), isFalse);
  });
  test('M341 English grocery and delivery brands stay distinct', () {
    expect(waffraRecognizedMerchantLeaf('Keemart', income: false),
        'بقالة وتموين / سوبرماركت');
    expect(waffraRecognizedMerchantLeaf('Keeta', income: false),
        'مطاعم وكافيهات / توصيل الطعام');
  });
}

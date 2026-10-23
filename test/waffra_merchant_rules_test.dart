import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main() {
 test('M153: identical merchant spellings share one safe key',(){
  const first='شراء PoS\nبـSAR 72.01\nلـSHAWARMA H\n15/10/26 16:09';
  const second='شراء PoS\nبـSAR 83.90\nلـshawerma h\n11/10/26 11:25';
  expect(waffraMerchantName(first),'SHAWARMA H');
  expect(waffraMerchantKey(first),'shawarma h');
  expect(waffraMerchantKey(second),'shawarma h');
 });
 test('M153: incoming/outgoing name extraction ignores bank numbers',(){
  const incoming='حوالة داخلية واردة بـSR 15.50\nلـ9288\nمن4388;انس الشايب';
  const outgoing='حوالة داخلية صادرة بـSR 60\nمن9288\nلـ4643;عبدالله العتوم';
  expect(waffraMerchantName(incoming,income:true),'انس الشايب');
  expect(waffraMerchantKey(incoming,income:true),'انس الشايب');
  expect(waffraMerchantName(outgoing),'عبدالله العتوم');
  expect(waffraMerchantKey(outgoing),'عبدالله العتوم');
  expect(waffraMerchantKey('حوالة واردة من 9288 مبلغ 15.50 ريال'),isNull);
 });
 test('M153: known merchant maps to an existing real leaf',(){
  expect(waffraRecognizedMerchantLeaf('OPENAI* CHATGPT SUBSCR',income:false),
   'اشتراكات رقمية / اشتراكات ذكاء اصطناعي');
  expect(waffraRecognizedMerchantLeaf('SHAWARMA H',income:false),
   'مطاعم وكافيهات / وجبات سريعة');
  expect(waffraRecognizedMerchantLeaf('ALHUSSAIN',income:false),isNull);
  expect(waffraFallbackSmsParent(income:true,transfer:true),'حوالات واردة');
  expect(waffraFallbackSmsParent(income:false,transfer:true),'تحويلات');
  expect(waffraFallbackSmsParent(income:false,transfer:false),'أخرى');
 });
}

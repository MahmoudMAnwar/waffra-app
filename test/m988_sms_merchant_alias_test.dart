import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main(){
 test('M988 known aliases yield same safe leaf without changing learning keys',(){
  const aliases=<String,String>{
   'Al Othaim':'بقالة وتموين / سوبرماركت',
   'أسواق العثيم':'بقالة وتموين / سوبرماركت',
   'Al Nahdi':'صحة / صيدلية وأدوية',
   'Nahdi':'صحة / صيدلية وأدوية',
   'صيدليات النهدي':'صحة / صيدلية وأدوية',
   'Hunger Station':'مطاعم وكافيهات / توصيل الطعام',
   'Star Bucks':'مطاعم وكافيهات / مقاهي',
   'McDonald S':'مطاعم وكافيهات / وجبات سريعة',
  };
  for(final row in aliases.entries){
   expect(waffraRecognizedMerchantLeaf(row.key,income:false),row.value,
    reason:'Distinct safe merchant variant ${row.key}');
  }
  // Store keys are unchanged: this mapping is category-only.
  expect(waffraNormalizeMerchantName('Al Othaim'),'al othaim');
 });
 test('M988 merchant aliases never classify incoming money',(){
  expect(waffraRecognizedMerchantLeaf('Al Nahdi',income:true),isNull);
  expect(waffraRecognizedMerchantLeaf('Al Othaim',income:true),isNull);
 });
 test('M988 payment rails, unknown senders and account numbers stay unknown',(){
  for(final text in ['STC Pay','Mada','AlRajhi','Account 1234']){
   expect(waffraRecognizedMerchantLeaf(text,income:false),isNull);
  }
 });
}

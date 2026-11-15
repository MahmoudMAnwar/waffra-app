import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M998 25 more Saudi merchant spellings map to exact existing leaf',(){
  const aliases=<String,String>{
   'Al Othaim Super Market':'بقالة وتموين / سوبرماركت',
   'Othaim Market':'بقالة وتموين / سوبرماركت',
   'أسواق عبدالله العثيم':'بقالة وتموين / سوبرماركت',
   'Abdullah Al Othaim':'بقالة وتموين / سوبرماركت',
   'Al Nahdi Pharmacies':'صحة / صيدلية وأدوية',
   'صيدلية النهدي':'صحة / صيدلية وأدوية',
   'Bin Dawood':'بقالة وتموين / سوبرماركت',
   'Bin Dawud':'بقالة وتموين / سوبرماركت',
   'Tamimi Markets':'بقالة وتموين / سوبرماركت',
   'اسواق التميمي':'بقالة وتموين / سوبرماركت',
   'Panda Supermarket':'بقالة وتموين / سوبرماركت',
   'هايبر بنده':'بقالة وتموين / سوبرماركت',
   'Danube Stores':'بقالة وتموين / سوبرماركت',
   'Danube Supermarket':'بقالة وتموين / سوبرماركت',
   'Keeta Food':'مطاعم وكافيهات / توصيل الطعام',
   'Jahez Food':'مطاعم وكافيهات / توصيل الطعام',
   'Hunger Station KSA':'مطاعم وكافيهات / توصيل الطعام',
   'Al Baik':'مطاعم وكافيهات / وجبات سريعة',
   'McDonalds SA':'مطاعم وكافيهات / وجبات سريعة',
   'AlJarir Bookstore':'تسوّق / قرطاسية',
   'Jarir Bookstore':'تسوّق / قرطاسية',
   'Amazon Saudi Arabia':'تسوّق / تسوق إلكتروني',
   'Noon Saudi':'تسوّق / تسوق إلكتروني',
   'STC Telecom SA':'فواتير / جوال',
   'Saudi Electricity Company':'فواتير / كهرباء',
   'Riyadh Metro Bus':'مواصلات / مترو وحافلات',
  };
  for(final row in aliases.entries){
   expect(waffraRecognizedMerchantLeaf(row.key,income:false),
    row.value,reason:row.key);
   expect(waffraRecognizedMerchantLeaf(row.key,income:true),
    isNull,reason:'Incoming money cannot infer merchant category');
  }
 });

 test('M998 explicit bilingual merchant fields, never arbitrary bank text',(){
  const cases=<String,String>{
   'Purchase Card 20 SAR\nMerchant Name: Al Othaim':'Al Othaim',
   'Purchase Card 20 SAR\nStore Name: Nahdi':'Nahdi',
   'Purchase Card 20 SAR\nStore: Jarir':'Jarir',
   'شراء بمبلغ ٣٠ ريال\nالتاجر: النهدي':'النهدي',
   'شراء بمبلغ ٣٠ ريال\nاسم التاجر: العثيم':'العثيم',
   'شراء بمبلغ ٣٠ ريال\nالمتجر: جرير':'جرير',
   'Purchase Card 20 SAR\nShop: Starbucks':'Starbucks',
  };
  for(final item in cases.entries){
   expect(waffraMerchantName(item.key),item.value,reason:item.key);
  }
  for(final bad in const <String>[
   'Merchant: OTP 445566','Merchant Name: Account **1234',
   'Store: Card 123456','التاجر: رمز التحقق ١٢٣٤٥٦',
   'Merchant: IBAN SA 123456',
  ]){expect(waffraMerchantName(bad),isNull,reason:bad);}
 });

 test('M998 payment rails and masked ID cannot become merchant category',(){
  for(final name in const <String>[
   'STC Pay','Mada','AlRajhi','Account 1234',
   'OTP 123456','PIN 123456','Card **1234',
  ]){
   expect(waffraRecognizedMerchantLeaf(name,income:false),isNull,
    reason:name);
  }
 });

 test('M998 only confirmed manual review creates category hint, no autoPost',(){
  final learned=WaffraSmsLocalRules.manualCategoryPattern(
   description:'Al Othaim',category:'بقالة وتموين / سوبرماركت',
   income:false);
  expect(learned,isNotNull);
  expect(learned!.resolvedKind,'expense');
  expect(learned.autoPost,isFalse);
  expect(learned.sender,isEmpty);
  // No chosen account: the existing rule schema uses an empty ID,
  // not null. Either way this can never authorize an account or money.
  expect(learned.accountId,isEmpty);
  final saved=WaffraSmsLocalRules.upsertLearned(
   existing:const [],candidate:learned);
  expect(saved.length,1);
  // A second user-approved category conflict must not overwrite the first.
  final conflicting=WaffraSmsLocalRules.manualCategoryPattern(
   description:'Al Othaim',category:'مطاعم وكافيهات / مطاعم شعبية',
   income:false)!;
  final preserved=WaffraSmsLocalRules.upsertLearned(
   existing:saved,candidate:conflicting);
  expect(preserved.length,1);
  expect(preserved.single.category,'بقالة وتموين / سوبرماركت');
 });
}

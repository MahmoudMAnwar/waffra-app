import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
 BudgetCategory, defaultCategories, waffraSmartSmsReviewCategory;
import 'package:waffra/waffra_merchant_rules.dart';

void main(){
 const posMedical='شراء عبر نقاط البيع بطاقة: **6314 MADA مبلغ: 33.81 SAR لدى: Marakez Medical Compan في: 2026-11-18 18:51 الرصيد المتبقي: ريال 93.95';
 const posPanda='شراء عبر نقاط البيع بطاقة: **6314 MADA مبلغ: 75 SAR لدى: PANDA RETAIL في: 2026-11-07 16:06 الرصيد المتبقي: ريال 627.43';
 const posStarbucks='شراء عبر نقاط البيع بطاقة: **6314 MADA مبلغ: 20 SAR لدى: Starbucks في: 2026-11-07 16:06 الرصيد المتبقي: ريال 627.43';

 BudgetCategory c(String id,String name,{String parentId='',
  bool income=false,bool active=true})=>BudgetCategory(
  id:id,name:name,parentId:parentId,income:income,
  icon:'category',color:0xFF087A54,categoryActive:active);

 test('M1047 inline Saudi POS merchant extraction keeps amount and card private',(){
  expect(waffraMerchantName(posMedical),'Marakez Medical Compan');
  expect(waffraMerchantName(posPanda),'PANDA RETAIL');
  expect(waffraMerchantName(posStarbucks),'Starbucks');
  expect(waffraMerchantName(
   'Purchase Card Amount: 38 SAR Merchant: Al Nahdi On: 2026-11-19 13:12'),
   'Al Nahdi');
  // Bank SMS can put an amount AFTER the merchant on the same line.
  // The amount, date and bank suffix never become part of merchant identity.
  expect(waffraMerchantName(
   'شراء نقاط بيع لدى: Al Nahdi مبلغ: 20 SAR في: 2026-11-18'),
   'Al Nahdi');
  expect(waffraMerchantName(
   'Purchase Card Merchant: Starbucks Amount: 20 SAR On: 2026-11-18'),
   'Starbucks');
  expect(waffraMerchantName(
   'شراء نقاط بيع لدى: Marakez Medical Compan المبلغ: 33.81 SAR في: 2026-11-18'),
   'Marakez Medical Compan');
  for(final unsafe in [
   'شراء نقاط بيع مبلغ: 10 SAR لدى: Card **6314 في: 2026-11-19',
   'شراء نقاط بيع مبلغ: 10 SAR لدى: Account 123456 في: 2026-11-19',
   'شراء نقاط بيع مبلغ: 10 SAR لدى: OTP 123456 في: 2026-11-19',
  ]){
   expect(waffraMerchantName(unsafe),isNull,reason:unsafe);
  }
 });

 test('M1047 bank SMS recommends main and leaf from actual merchant, not bank',(){
  final categories=defaultCategories();
  final medical=waffraSmartSmsReviewCategory(categories,
    sms:posMedical,income:false,
    proposed:'أخرى / مصروف غير مصنف',ownerLearned:false);
  expect(medical.parent?.name,'صحة');
  expect(medical.leaf?.name,'صحة / عيادات');

  final panda=waffraSmartSmsReviewCategory(categories,
    sms:posPanda,income:false,
    proposed:'أخرى / مصروف غير مصنف',ownerLearned:false);
  expect(panda.parent?.name,'بقالة وتموين');
  expect(panda.leaf?.name,'بقالة وتموين / سوبرماركت');
  final coffee=waffraSmartSmsReviewCategory(categories,
    sms:posStarbucks,income:false,
    proposed:'أخرى / مصروف غير مصنف',ownerLearned:false);
  expect(coffee.parent?.name,'مطاعم وكافيهات');
  expect(coffee.leaf?.name,'مطاعم وكافيهات / مقاهي');

  expect(waffraSmartSmsReviewCategory(categories,
   sms:'شراء نقاط بيع لدى: Al Nahdi مبلغ: 20 SAR في: 2026-11-18',
   income:false,proposed:'أخرى / مصروف غير مصنف',
   ownerLearned:false).leaf?.name,'صحة / صيدلية وأدوية');
 });

 test('M1047 explicit owner-learned category beats merchant catalog suggestion',(){
  final result=waffraSmartSmsReviewCategory(defaultCategories(),
   sms:posStarbucks,income:false,
   proposed:'تسوّق / تسوق إلكتروني',ownerLearned:true);
  expect(result.parent?.name,'تسوّق');
  expect(result.leaf?.name,'تسوّق / تسوق إلكتروني');
 });

 test('M1047 separate messages from same bank do not share last category',(){
  final catalog=defaultCategories();
  final first=waffraSmartSmsReviewCategory(catalog,
   sms:posPanda,income:false,proposed:'',ownerLearned:false);
  final second=waffraSmartSmsReviewCategory(catalog,
   sms:posStarbucks,income:false,proposed:'',ownerLearned:false);
  expect(first.leaf?.name,'بقالة وتموين / سوبرماركت');
  expect(second.leaf?.name,'مطاعم وكافيهات / مقاهي');
  expect(second.leaf?.name,isNot(first.leaf?.name));
 });

 test('M1047 no prediction for outgoing personal transfer, incoming or unknown',(){
  final categories=defaultCategories();
  for(final sms in [
   'حوالة داخلية صادرة من: محمود مبلغ: SAR 10 الى: Starbucks حساب:**7856 في:2026-11-19 15:08',
   'شراء عبر نقاط البيع بطاقة: **6314 MADA مبلغ: 23 SAR لدى: UNKNOWN SHOP في: 2026-11-19 15:08',
   'رمز التحقق OTP 123456 لدى Starbucks',
   'عملية مرفوضة شراء لدى Starbucks مبلغ SAR 25',
  ]){
   final proposed=waffraSmartSmsReviewCategory(categories,
    sms:sms,income:false,proposed:'',ownerLearned:false);
   expect(proposed.leaf,isNull,reason:sms);
  }
  expect(waffraSmartSmsReviewCategory(categories,
   sms:posStarbucks,income:true,proposed:'',ownerLearned:false)
   .leaf,isNull);
 });

 test('M1047 inactive and duplicate merchant categories are never auto-selected',(){
  final categories=<BudgetCategory>[
   c('health','صحة'),
   c('clinic','صحة / عيادات',parentId:'health',active:false),
   c('other','أخرى'),
   c('other-exp','أخرى / مصروف غير مصنف',parentId:'other'),
  ];
  final inactive=waffraSmartSmsReviewCategory(categories,
   sms:posMedical,income:false,
   proposed:'',ownerLearned:false);
  expect(inactive.leaf,isNull);
  categories.removeWhere((c)=>c.id=='clinic');
  categories.add(c('clinic','صحة / عيادات',parentId:'health'));
  categories.add(c('other-clinic','صحة / عيادات',parentId:'other'));
  final ambiguous=waffraSmartSmsReviewCategory(categories,
   sms:posMedical,income:false,
   proposed:'',ownerLearned:false);
  expect(ambiguous.leaf,isNull);
 });

 test('M1047 bank suggestion is review-only and retains owner confirmation',(){
  final r=waffraSmartSmsReviewCategory(defaultCategories(),
   sms:posMedical,income:false,proposed:'',ownerLearned:false);
  expect(r.leaf,isNotNull);
  // No writes, ACK, account selection or transaction amount is returned.
  expect(r.leaf!.name,'صحة / عيادات');
 });
}

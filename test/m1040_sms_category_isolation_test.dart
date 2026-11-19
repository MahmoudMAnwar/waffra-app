import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main() {
 test('confirmed category does not spread through generic outgoing bank heading', () {
  const first='حوالة داخلية صادرة من: محمود مبلغ:SAR 1.00 الى: اسراء حساب:**7856 في:15:08 2026-11-02';
  const second='حوالة داخلية صادرة من: محمود مبلغ:SAR 27.00 الى: شخص آخر حساب:**9988 في:15:09 2026-11-02';
  final learned=WaffraSmsLocalRules.suggestedGlobalRule(
   body:first,sender:'BANK',kind:'expense',category:'فواتير / جوال',
   confidentOnly:true,
  );
  // General bank operation words are insufficient evidence of a shared category.
  if(learned!=null) {
   expect(learned.keywords.any((word)=>word.contains('حوالة')),isFalse);
   expect(WaffraSmsLocalRules.matches(learned,second,sender:'BANK'),isFalse);
  }
 });

 test('legacy heading-only finance rule cannot override other SMS categories', () {
  const legacy=WaffraSmsLocalRule(
   id:'smart_legacy_heading',name:'مصروف معروف',kind:'expense',
   income:false,category:'فواتير / جوال',sender:'BANK',
   keywords:['حوالة داخلية صادرة'],matchAll:true,autoPost:false,
  );
  expect(WaffraSmsLocalRules.matches(legacy,
   'حوالة داخلية صادرة مبلغ:SAR 22 الى: شخص آخر',sender:'BANK'),isFalse);
 });
 test('generic bank directions do not create manual category hints', () {
  expect(WaffraSmsLocalRules.manualCategoryPattern(
   description:'حوالة داخلية صادرة',category:'فواتير / جوال',income:false),isNull);
  expect(WaffraSmsLocalRules.manualCategoryPattern(
   description:'شراء عبر نقاط البيع',category:'فواتير / جوال',income:false),isNull);
  final specific=WaffraSmsLocalRules.manualCategoryPattern(
   description:'ستاربكس',category:'مطاعم / مقاهي',income:false);
  expect(specific,isNotNull);
  expect(WaffraSmsLocalRules.matches(specific!,
   'شراء لدى ستاربكس مبلغ 30 SAR',sender:'BANK'),isTrue);
 });

 test('legacy senderless manual category ignores generic operation terms', () {
  const legacy=WaffraSmsLocalRule(
   id:'manual_legacy_generic',name:'حوالة داخلية صادرة',kind:'expense',
   income:false,category:'فواتير / جوال',sender:'',
   keywords:['داخليه','صادره'],matchAll:false,autoPost:false);
  expect(WaffraSmsLocalRules.matches(legacy,
   'حوالة داخلية صادرة مبلغ SAR 50',sender:'BANK'),isFalse);
 });

}

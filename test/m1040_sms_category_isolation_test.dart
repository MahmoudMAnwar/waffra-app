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
}

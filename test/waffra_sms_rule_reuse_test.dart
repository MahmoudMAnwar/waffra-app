import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 group('M452 SMS rule reuse',(){
  const groceries=WaffraSmsLocalRule(
   id:'groceries-local-v1',name:'Panda purchases',
   keywords:['شراء','بنده'],income:false,
   category:'بقالة وتموين / سوبرماركت',
   matchAll:true,sender:'AlRajhi',
  );
  test('same sender and keywords reuse existing personalized expense rule',(){
   final matched=WaffraSmsLocalRules.resolve(
    body:'تم شراء من بنده بمبلغ 75 ريال سعودي',
    sender:'AlRajhi',
    bankKind:WaffraBankOperationKind.expense,
    custom:[groceries]);
   expect(matched?.id,groceries.id);
   expect(matched?.income,false);
  });
  test('same keywords from other sender never silently inherit owner rule',(){
   final matched=WaffraSmsLocalRules.resolve(
    body:'تم شراء من بنده بمبلغ 75 ريال',
    sender:'UnknownSender',
    bankKind:WaffraBankOperationKind.expense,
    custom:[groceries]);
   expect(matched?.id,isNot(groceries.id));
  });
  test('income bank evidence cannot become expense through keyword rule',(){
   final matched=WaffraSmsLocalRules.resolve(
    body:'تم شراء من بنده، المبلغ أضيف كرصيد وارد',
    sender:'AlRajhi',
    bankKind:WaffraBankOperationKind.income,
    custom:[groceries]);
   expect(matched,isNull);
  });
  test('same match never reclassifies transfer as an expense or income',(){
   final matched=WaffraSmsLocalRules.resolve(
    body:'شراء من بنده ثم تحويل بين الحسابات',
    sender:'AlRajhi',
    bankKind:WaffraBankOperationKind.transfer,
    custom:[groceries]);
   expect(matched,isNull);
  });
  test('unsafe account numbers and verification digits cannot be keywords',(){
   for(final bad in ['123456','حساب 11112222','رمز 1234','otp','balance','IBAN']){
    expect(WaffraSmsLocalRules.safeKeyword(bad),false,reason:bad);
   }
  });
 });
}

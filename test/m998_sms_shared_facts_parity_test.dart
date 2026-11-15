import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';
import 'package:waffra/waffra_sms_saudi_template_registry.dart';

void main(){
 test('M998 public and pre-parsed masked-account suggestions are identical',(){
  const samples=<String>[
   'Purchase Card\nAmount: 20 SAR\nAccount: **1234',
   'تم شراء ٢٠ ريال من الحساب **١٢٣٤',
   'Incoming Transfer\nAmount: 50 SAR\nTo Account: **4321',
   'Salary Deposit 7000 SAR\nAccount **1234',
   'Pending Purchase Card 50 SAR\nAccount **1234',
   'OTP 445566\nAccount: **1234',
   'Purchase 15 USD\nAccount: **1234',
   'حوالة صادرة من حساب **١٢٣٤ إلى حساب **٤٣٢١',
   'Credit Card Payment 100 SAR\nAccount **1234',
  ];
  for(final sms in samples){
   final facts=WaffraBankSmsFactsParser.parse(sms);
   for(final income in [false,true]){
    final old=WaffraBankSmsFactsParser.suggestedAccountLastFour(
     sms,income:income);
    final shared=WaffraBankSmsFactsParser.suggestedAccountLastFour(
     sms,income:income,preParsed:facts);
    expect(shared,old,reason:sms);
   }
   final templated=WaffraSaudiSmsTemplateRegistry.identify(
    providerId:'rajhi',body:sms,securityChallenge:facts.securityChallenge);
   final legacy=WaffraSaudiSmsTemplateRegistry.identify(
    providerId:'rajhi',body:sms);
   expect(templated?.family,legacy?.family,reason:sms);
  }
 });

 test('M998 security challenge is immutable even on mixed bank messages',(){
  const messages=<String>[
   'OTP 445566',
   'رمز التحقق ١٢٣٤٥٦',
   'Purchase Card 100 SAR\nOTP 555555',
   'تمت إضافة المستفيد\nرمز التأكيد ١٢٣٤٥٦',
  ];
  for(final sms in messages){
   final facts=WaffraBankSmsFactsParser.parse(sms);
   expect(facts.securityChallenge,isTrue,reason:sms);
   expect(facts.pending,isTrue,reason:sms);
   final ctx=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
   expect(ctx.facts.securityChallenge,isTrue);
   expect(ctx.principalSar,isNull);
   expect(ctx.accountLastFour,isNull);
   expect(ctx.requiresReview,isTrue);
  }
 });

 test('M998 one structured parse shares facts without banking permission',(){
  const posted='Purchase Card\nAmount: 20 SAR\nAccount: **1234';
  final facts=WaffraBankSmsFactsParser.parse(posted);
  final ctx=WaffraSmsStructuredBankContext.parse(posted,sender:'AlRajhi');
  expect(ctx.facts.kind,facts.kind);
  expect(ctx.facts.sourceSuffix,facts.sourceSuffix);
  expect(ctx.accountLastFour,
    WaffraBankSmsFactsParser.suggestedAccountLastFour(
      posted,income:false,preParsed:facts));
  expect(ctx.templateFamily,'purchase');
  expect(ctx.referenceAmountSar,20);
  expect(ctx.principalSar,20);
  expect(ctx.requiresReview,isFalse);
  final unknown=WaffraSmsStructuredBankContext.parse(
   posted,sender:'Unverified-Person');
  expect(unknown.accountLastFour,isNull);
  expect(unknown.templateFamily,isNull);
 });

 test('M998 incomplete and mixed financial events remain review-only',(){
  const composite='Purchase Card 20 SAR\nOutgoing Transfer 15 SAR';
  final ctx=WaffraSmsStructuredBankContext.parse(composite,
   sender:'AlRajhi');
  expect(ctx.composite,isTrue);
  expect(ctx.principalSar,isNull);
  expect(ctx.templateFamily,isNull);
  expect(ctx.requiresReview,isTrue);
 });
}

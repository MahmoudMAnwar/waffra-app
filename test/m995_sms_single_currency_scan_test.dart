import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show BankParser;
import 'package:waffra/waffra_sms_multicurrency_review.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';

void main(){
 test('M995 original action amount is identical with precomputed currency set',(){
  const texts=<String>[
   'Purchase Card\nAmount: 120.00 SAR\nAccount: **1234',
   'شراء ٣٠٫٥٠ ريال\nحساب: **١٢٣٤',
   'Purchase Card 20 USD',
   'Purchase Card 20 SAR; Purchase 50 USD',
   'Purchase Card 50 SAR\nAvailable balance 1200 SAR\nFee: 2 SAR',
   'Purchase Card 100 SAR\nRef: ABC12345',
   'حوالة واردة ١٬٥٠٠٫٠٠ ريال',
   'OTP 123456',
  ];
  for(final body in texts){
   final currencies=WaffraSmsCurrencies.currenciesForMessage(body);
   final oldAmount=WaffraSmsCurrencies.originalAmount(body);
   final shared=WaffraSmsCurrencies.originalAmount(
    body,detectedCurrencies:currencies);
   expect(shared?.currency,oldAmount?.currency,reason:body);
   expect(shared?.amount,oldAmount?.amount,reason:body);
  }
 });

 test('M995 BankParser direct and shared context stay equivalent',(){
  const texts=<String>[
   'Purchase Card\nAmount: 120.00 SAR\nAccount: **1234',
   'Purchase Card 100 SAR\nRef: ABC12345',
   'تم إيداع راتب ٥٠٠٠ ريال في حسابك',
   'Outgoing Transfer 75 SAR',
   'Incoming Transfer 20 SAR',
   'Declined Transaction\nPurchase 20 SAR',
   'Credit Card Payment 100 SAR',
   'Purchase Card 50 USD',
   'Purchase Card 20 SAR; Purchase 50 USD',
   'Available balance 500 SAR',
   'رمز التحقق: ١٢٣٤٥٦',
  ];
  for(final body in texts){
   final context=WaffraSmsStructuredBankContext.parse(
    body,sender:'AlRajhi');
   final legacy=BankParser.parse(body);
   final reused=BankParser.parse(body,
    detectedCurrencies:context.sourceCurrencies,
    sourceAmount:context.sourceAmount);
   expect(reused.amount,legacy.amount,reason:body);
   expect(reused.income,legacy.income,reason:body);
   expect(reused.requiresCurrencyReview,
    legacy.requiresCurrencyReview,reason:body);
   expect(reused.currencyCode,legacy.currencyCode,reason:body);
  }
 });

 test('M995 indexed 2000 repeats never infer foreign money as SAR',(){
  const body='Purchase Card 20 USD\nRef: ABC12345';
  final facts=WaffraSmsStructuredBankContext.parse(body,sender:'AlRajhi');
  for(var n=0;n<2000;n++){
   final parsed=BankParser.parse(body,
    detectedCurrencies:facts.sourceCurrencies,
    sourceAmount:facts.sourceAmount);
   expect(parsed.amount,isNull);
   expect(parsed.requiresCurrencyReview,isTrue);
  }
 });

 test('M995 worker reuses structured evidence but old parser API remains',(){
  final src=File('lib/main.dart').readAsStringSync();
  final context=File('lib/waffra_sms_structured_bank_context.dart')
   .readAsStringSync();
  expect(src,contains('sourceAmount:contextFacts.sourceAmount'));
  expect(src,contains('detectedCurrencies:contextFacts.sourceCurrencies'));
  expect(src,contains('static BankResult parse(String original,{'));
  expect(context,contains('detectedCurrencies:sourceCurrencies'));
 });
}

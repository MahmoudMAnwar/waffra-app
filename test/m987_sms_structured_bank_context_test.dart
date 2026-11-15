import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 test('M987 Saudi purchase: verified principal distinct from balance and fee',(){
  const msg='Purchase Card\nAmount: 120.00 SAR\nAccount: **1234\nAvailable balance 580.00 SAR\nFee 2.00 SAR';
  final parsed=WaffraSmsStructuredBankContext.parse(msg,sender:'AlRajhi');
  expect(parsed.providerId,'rajhi');
  expect(parsed.facts.kind,WaffraBankOperationKind.expense);
  expect(parsed.composite,isFalse);
  expect(parsed.principalSar,120.0);
  expect(parsed.accountLastFour,'1234');
 });
 test('M987 failed or OTP money remains review and has no amount hint',(){
  const msg='Declined Transaction\nPurchase 120 SAR\nOTP 445566';
  final parsed=WaffraSmsStructuredBankContext.parse(msg,sender:'AlRajhi');
  expect(parsed.pending,isTrue);
  expect(parsed.principalSar,isNull);
  expect(parsed.requiresReview,isTrue);
 });
 test('M987 composite two independent actions can never be classified as one',(){
  const msg='Purchase Card 50 SAR; Outgoing Transfer 75 SAR';
  final parsed=WaffraSmsStructuredBankContext.parse(msg,sender:'AlRajhi');
  expect(parsed.composite,isTrue);
  expect(parsed.principalSar,isNull);
  expect(parsed.requiresReview,isTrue);
 });
 test('M987 foreign currency does not become a SAR posting hint',(){
  const msg='Purchase Card\nAmount: 20.00 USD';
  final parsed=WaffraSmsStructuredBankContext.parse(msg,sender:'AlRajhi');
  expect(parsed.principalSar,isNull);
  expect(parsed.requiresReview,isTrue);
 });
 test('M987 unknown sender does not create bank ownership evidence',(){
  const msg='Purchase Card\nAmount: 30 SAR\nAccount: **1234';
  final parsed=WaffraSmsStructuredBankContext.parse(msg,sender:'Unknown42');
  expect(parsed.providerId,isNull);
  expect(parsed.accountLastFour,isNull);
 });
}

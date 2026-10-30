import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main(){
 const cliq='JOD198.000 has been credited to '
  '0119*500 from ANAS ALSHAYEB as CliQ transfer. Balance 201.632JOD';
 test('M300 attached JOD recognized, no UNKNOWN and no balance transaction',(){
  expect(WaffraSmsCurrencies.currenciesForMessage(cliq),{'JOD'});
  expect(WaffraSmsCurrencies.summarize([cliq]).summary,'JOD: 1');
  expect(WaffraSmsCurrencies.originalAmountPreview(cliq),'198.000 JOD');
  expect(WaffraSmsCurrencies.originalAmountPreview(
   'JOD198.000 credited Balance 201.632JOD'),'198.000 JOD');
  expect(WaffraSmsCurrencies.requiresReviewForSarLedger(cliq),isTrue);
  final parsed=BankParser.parse(cliq);
  expect(parsed.income,isTrue);
  expect(parsed.currencyCode,'JOD');
  expect(parsed.amount,isNull);
  expect(parsed.requiresCurrencyReview,isTrue);
 });
 test('M300 currency detection ignores ordinary three-letter verbs',(){
  expect(WaffraSmsCurrencies.currenciesForMessage(
   '198.000 has been credited Balance 201.632JOD'),isEmpty);
  expect(WaffraSmsCurrencies.currenciesForMessage(
   'JOD198.000 has been credited Balance 201.632JOD'),{'JOD'});
  expect(WaffraSmsCurrencies.currenciesForMessage(
   'Amount: MXN 200'),{'UNKNOWN'});
 });
 test('M300 three decimal JOD cannot lose minor-unit precision',(){
  expect(WaffraCurrencyMinor.digits('JOD'),3);
  expect(WaffraCurrencyMinor.digits('IQD'),3);
  expect(WaffraCurrencyMinor.exact(198,'JOD'),198000);
  expect(WaffraCurrencyMinor.exact(201.632,'JOD'),201632);
  expect(WaffraCurrencyMinor.exact(198.0001,'JOD'),isNull);
  expect(WaffraCurrencyMinor.digits('SAR'),2);
 });
 test('M300 no accidental ledger conversion or false field-error notice',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('WaffraSmsCurrencies.originalAmountPreview('));
  expect(src,contains("'waffra-sms-review-notice'"));
  expect(src,contains('errorText:pasteAttempted&&pasted.text.trim().isEmpty'));
  expect(src,contains('requiresCurrencyReview:true'));
 });
}

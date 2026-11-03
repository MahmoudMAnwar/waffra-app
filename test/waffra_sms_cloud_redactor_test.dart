import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_cloud_redactor.dart';

void main(){
 test('M421 blocks OTP even if a financial amount is present',(){
  expect(WaffraSmsCloudRedactor.redact(
   'Verification Code 1234 for Card Purchase SAR 75.00'),isNull);
  expect(WaffraSmsCloudRedactor.redact(
   'رمز التحقق 1234 لعملية شراء 75 ريال'),isNull);
 });
 test('M421 masks full card IDs and long transaction references',(){
  final result=WaffraSmsCloudRedactor.redact(
   'Card Purchase SAR 75.00 Card: 1234567812345678 '
   'Reference: PZY123456ABC77');
  expect(result,isNotNull);
  expect(result,contains('SAR 75.00'));
  expect(result,contains('[identifier-redacted]'));
  expect(result,contains('[reference-redacted]'));
  expect(result, isNot(contains('1234567812345678')));
  expect(result, isNot(contains('PZY123456ABC77')));
 });
 test('M421 redacts IBAN and personal recipient without losing action',(){
  final result=WaffraSmsCloudRedactor.redact(
   'Outgoing Transfer SAR 120.00\n'
   'To: Test Receiver Name\n'
   'IBAN: SA0380000000608010167519');
  expect(result,isNotNull);
  expect(result,contains('SAR 120.00'));
  expect(result, isNot(contains('Test Receiver Name')));
  expect(result, isNot(contains('SA038')));
 });
 test('M421 never uploads ordinary conversations or marketing',(){
  expect(WaffraSmsCloudRedactor.redact(
   'Hello Mahmoud! Your meeting is tomorrow at 11am.'),isNull);
  expect(WaffraSmsCloudRedactor.redact(
   'Enjoy our weekend special deal, limited-time sale!'),isNull);
 });
 test('M421 Arabic finance message normalizes numerals locally',(){
  final data=WaffraSmsCloudRedactor.redact(
   'تم خصم ٧٥٫٠٠ ريال مقابل شراء وقود من حساب 1234567890');
  expect(data,isNotNull);
  expect(data,contains('ريال'));
  expect(data, isNot(contains('1234567890')));
 });
}

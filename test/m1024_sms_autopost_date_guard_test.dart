import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main(){
 test('M1024 no explicit bank transaction time is never an AutoPost date',(){
  const sms='شراء ببطاقة مدى\nالمبلغ 45.00 SAR\nالحساب **1244';
  expect(bankSmsDate(sms,referenceDate:DateTime(2026,11,17,1,15)),isNull);
  final source=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(source,contains('if(date==null||bankSmsHasUnverifiedTimestamp(body,referenceDate:arrived))'));
  expect(source,contains('date:date,notes:body'));
  expect(source,isNot(contains('date:date??arrived')));
 });
 test('M1024 explicit verified date survives delayed SMS delivery',(){
  const sms='شراء نقاط بيع\nAmount: 45 SAR\n16/11/2026 09:25';
  final parsed=bankSmsDate(sms,referenceDate:DateTime(2026,11,17,20));
  expect(parsed,DateTime(2026,11,16,9,25));
 });
 test('M1024 malformed 318-11-2026 remains unverified',(){
  const sms='شراء 85 SAR\n318-11-2026 09:25';
  expect(bankSmsHasUnverifiedTimestamp(sms),isFalse);
  expect(bankSmsDate(sms),isNull);
 });
}

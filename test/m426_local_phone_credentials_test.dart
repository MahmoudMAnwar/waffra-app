import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

void main(){
 test('M426 Saudi phone only, no paid verification',(){
  expect(WaffraLocalPhoneCredentials.validPhone('0501234567'),true);
  for(final bad in ['050123','+966501234567','0712345678','abc']){
   expect(WaffraLocalPhoneCredentials.validPhone(bad),false);
  }
 });
 test('M426 strong password verifier is salted and never stores plaintext',
   ()async{
  final salt=List<int>.filled(32,7);
  final result=await WaffraLocalPhoneCredentials.deriveRecord(
   phone:'0501234567',password:'CorrectP@ssword12',testSalt:salt);
  expect(jsonEncode(result).contains('CorrectP@ssword12'),false);
  expect(await WaffraLocalPhoneCredentials.verifyRecord(result,
   phone:'0501234567',password:'CorrectP@ssword12'),true);
  expect(await WaffraLocalPhoneCredentials.verifyRecord(result,
   phone:'0501234567',password:'WrongPassword12'),false);
  expect(await WaffraLocalPhoneCredentials.verifyRecord(result,
   phone:'0599999999',password:'CorrectP@ssword12'),false);
 });
 test('M426 main sign in requires password and biometric, no OTP',(){
  final main=File('lib/main.dart').readAsStringSync();
  final signin=main.substring(main.indexOf('Future<void> _signIn()async{'),
    main.indexOf('String get maskedLastPhone{'));
  expect(signin,contains('WaffraLocalPhoneCredentials.verify('));
  expect(signin,contains('await widget.onSave(verifiedAccount)'));
  expect(signin,contains('if(!match){'));
  expect(signin,contains('phone:enteredPhone,password:signInPassword.text'));
  expect(signin.indexOf('await widget.onSave(verifiedAccount)'),
    greaterThan(signin.indexOf('if(!match){')));
  expect(main,contains('WaffraMandatoryBiometricGate('));
  expect(main,contains('locked=u!=null;'));
  expect(main,contains('if(freshSession)locked=true;'));
  expect(main,isNot(contains('WaffraPhoneSecureAuth')));
  expect(main,isNot(contains('enrollWithOtp')));
  expect(main,isNot(contains('requestCode:_requestVerifiedPhoneCode')));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M463 first-run login route precedes permission onboarding', () {
  final source=File('lib/main.dart').readAsStringSync();
  final start=source.indexOf('home:Builder(builder:(rootContext)=>PopScope(');
  expect(start,greaterThanOrEqualTo(0));
  final tail=source.substring(start);
  final login=tail.indexOf('profile==null||showLogin||');
  final consent=tail.indexOf('autoSmsConsentPending?WaffraAutoSmsConsentPage(');
  final gate=tail.indexOf('locked?WaffraMandatoryBiometricGate(');
  expect(login,greaterThanOrEqualTo(0));
  expect(consent,greaterThan(login),
   reason:'Never ask for SMS or notifications before registration/login');
  expect(gate,greaterThan(consent),
   reason:'Consent is after account creation and before the signed-in home');
  expect(tail,contains('onComplete:finishSmsPermissionChoice'));
  expect(tail,contains('LoginScreen(onSave:saveUser)'));
 });

 test('M463 permissions only after signed-in profile and once per install',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains('autoSmsConsentPending=Platform.isAndroid&&u!=null&&'));
  expect(source,contains('final needsSmsAccessAfterRegistration=Platform.isAndroid&&profile==null&&'));
  expect(source,contains('if(needsSmsAccessAfterRegistration)autoSmsConsentPending=true;'));
  expect(source,contains('await p.setBool(WaffraAutoSms.firstRunKey,true)'));
  final permissionPage=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  expect(permissionPage,contains('await WaffraAutoSms.optIn();'));
  expect(permissionPage,contains('await WaffraAutoSms.requestNotificationPermission();'));
 });
}

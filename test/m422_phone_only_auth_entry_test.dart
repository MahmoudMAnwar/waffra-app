import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 late String main;
 setUpAll(()=>main=File('lib/main.dart').readAsStringSync());

 test('M422 blocks all guest onboarding and hidden quick start',(){
  expect(main, isNot(contains("Start now — no sign in")));
  expect(main, isNot(contains("ابدأ الآن بدون تسجيل دخول")));
  expect(main, isNot(contains('Future<void> quickStart()async {')));
  expect(main, contains("profile!.provider.toLowerCase().contains('guest')"));
 });

 test('M422 registration uses phone only, no social identity chooser',(){
  final s=main.substring(main.indexOf('class _LoginScreenState'),
    main.indexOf('class ProfileForm extends StatefulWidget'));
  expect(s,contains("setState(()=>provider='Phone')"));
  expect(s, isNot(contains('Widget _socialBorder(')));
  expect(s, isNot(contains('demoSocial(')));
  expect(s,contains("إنشاء حساب برقم الجوال"));
 });

 test('M422 first onboarding step validates Saudi phone and both passwords',(){
  final section=main.substring(main.indexOf('Widget _phoneRegistrationForm()'),
    main.indexOf(' @override Widget build(BuildContext context){',
      main.indexOf('Widget _phoneRegistrationForm()')));
  expect(section,contains('waffraMobileFieldError(phone.text)'));
  expect(section,contains('FilteringTextInputFormatter.digitsOnly'));
  expect(section,contains('LengthLimitingTextInputFormatter(10)'));
  expect(section,contains('_nextPhoneRegistrationStep'));
  expect(section,contains('waffraPasswordFieldError(password.text)'));
  expect(section,contains('waffraConfirmPasswordFieldError'));
 });

 test('M422 second step requires name and gender without email or birthday',(){
  final s=main.substring(main.indexOf('Widget _phoneRegistrationForm()'),
   main.indexOf(' @override Widget build(BuildContext context){',
    main.indexOf('Widget _phoneRegistrationForm()')));
  expect(s,contains('controller:name'));
  expect(s,contains("['ذكر','أنثى']"));
  expect(s,isNot(contains('controller:email')));
  expect(s,isNot(contains('birthday')));
  expect(s,isNot(contains('widget.onSave(Person(')));
 });

 test('M422 does not silently overwrite existing Google or phone account',(){
  final s=main.substring(main.indexOf('class _LoginScreenState'),
    main.indexOf('class ProfileForm extends StatefulWidget'));
  expect(s,contains('if(registered!=null){'));
  expect(s,contains('legacyAccount'));
  expect(s,contains('continueLastLogin'));
  expect(s,contains('لازم نتحقق من حسابك القديم'));
 });

 test('M422 login retains explicit password challenge before profile save',(){
  final s=main.substring(main.indexOf('class _LoginScreenState'),
    main.indexOf('class ProfileForm extends StatefulWidget'));
  expect(s,contains('WaffraLocalPhoneCredentials.verify('));
  expect(s,contains('oldSalt:'));
  expect(s,contains('await widget.onSave(verifiedAccount)'));
  expect(s,contains('if(!match){'));
  expect(s,contains('hasRegisteredCredentials()'));
  expect(s,contains('signInPassword.text'));
  // The verified profile can only be saved AFTER matching secure credentials.
  expect(s.indexOf('await widget.onSave(verifiedAccount)'),
    greaterThan(s.indexOf('if(!match){')));
 });
}

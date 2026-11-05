import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
 late String main;
 setUpAll(()=>main=File('lib/main.dart').readAsStringSync());

 test('M463 app authentication always precedes first-run permissions',(){
  final a=main.indexOf('   startupError!=null?Scaffold(');
  final b=main.indexOf('   HomeScreen(key:ValueKey(language)',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  final route=main.substring(a,b);
  final login=route.indexOf('LoginScreen(onSave:saveUser)');
  final afterFresh=route.indexOf('(autoSmsConsentPending&&_smsConsentAfterVerifiedSignIn)?');
  final biometric=route.indexOf('locked?WaffraMandatoryBiometricGate');
  final afterRestore=route.indexOf('autoSmsConsentPending?WaffraAutoSmsConsentPage');
  expect(login,greaterThan(0));
  expect(afterFresh,greaterThan(login));
  expect(biometric,greaterThan(afterFresh));
  expect(afterRestore,greaterThan(biometric));
  expect(route,contains('onSignOut:logout'));
  expect(route,isNot(contains(
   "autoSmsConsentPending?WaffraAutoSmsConsentPage(\n    english:language=='en',onComplete:finishSmsPermissionChoice):\n   profile==null")));
 });

 test('M463 first clean install has only one account creation form',(){
  final login=main.substring(
   main.indexOf('class _LoginScreenState extends State<LoginScreen> {'),
   main.indexOf('class ProfileForm extends StatefulWidget {'));
  final registration=main.substring(
   main.indexOf(' Widget _phoneRegistrationForm(){'),
   main.indexOf(" @override Widget build(BuildContext context){\n  if(widget.initial==null&&widget.provider=='Phone')return _phoneRegistrationForm();"));
  expect(login,contains('if(!_registrationChecked){'));
  expect(login,contains('if(_freshSignup)return ProfileForm(provider:\'Phone\',onSave:widget.onSave);'));
  expect(login,contains('signInMode=oldUser?.provider.toLowerCase()==\'phone\';'));
  expect(login,contains("final hasSecureVerifier=await WaffraLocalPhoneCredentials"));
  expect(login,contains("final hasOldProfile=prefs.getString('waffra_profile')!=null;"));
  expect(login,contains("final hasLegacyVerifier=prefs.containsKey('waffra_local_password_hash')"));
  expect(login,contains('_freshSignup=raw==null&&!hasOldProfile&&!hasLegacyVerifier&&'));
  expect(registration,contains("Key('waffra-register-single-page')"));
  for(final key in const [
   'waffra-register-name','waffra-register-gender-male',
   'waffra-register-gender-female','waffra-register-phone',
   'waffra-register-password','waffra-register-confirm-password',
   'waffra-register-submit',
  ]){expect(registration,contains("Key('$key')"));}
  expect(registration,isNot(contains('controller:email')));
  expect(registration,isNot(contains('birthday')));
  expect(registration,contains('leading:widget.onBack==null?null:IconButton('));
 });

 test('M463 registration/login success precedes SMS prompt and OS biometrics',(){
  final save=main.substring(
   main.indexOf(' Future<void> saveUser(Person u)async {'),
   main.indexOf(' Future<void> setUiCountry('));
  expect(save,contains('await _accountWriteAuthority.saveProfile('));
  expect(save,contains('_smsConsentAfterVerifiedSignIn=needsSmsAccessAfterRegistration;'));
  expect(save.indexOf('await _accountWriteAuthority.saveProfile('),
    lessThan(save.indexOf('_smsConsentAfterVerifiedSignIn=needsSmsAccessAfterRegistration;')));
  expect(save,contains('if(freshSession)locked=true;'));
  final load=main.substring(
   main.indexOf(' Future<void> load()async {'),
   main.indexOf(' Future<void> finishSmsPermissionChoice()async{'));
  expect(load,contains('locked=u!=null;'));
  expect(load,contains('autoSmsConsentPending=Platform.isAndroid&&u!=null&&'));
  expect(main,contains('bool _smsConsentAfterVerifiedSignIn=false;'));
 });

 test('M463 Android SMS then notifications remains one-time, no AI opt in',(){
  final consent=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  final finish=main.substring(
   main.indexOf(' Future<void> finishSmsPermissionChoice()async{'),
   main.indexOf(' Future<void> intro()async {'));
  expect(consent,contains('await WaffraSmsCloudService.setConsent(false)'));
  expect(consent,contains('final smsAllowed=await WaffraAutoSms.optIn();'));
  expect(consent,contains('await WaffraAutoSms.requestNotificationPermission();'));
  expect(consent,contains('await widget.onComplete();'));
  expect(finish,contains('await p.setBool(WaffraAutoSms.firstRunKey,true)'));
  expect(finish,contains('_smsConsentAfterVerifiedSignIn=false;'));
  expect(consent,isNot(contains('importConsentMonthBankSms')));
 });
}

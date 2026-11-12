import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 late String main;
 setUpAll(()=>main=File('lib/main.dart').readAsStringSync());

 testWidgets('M463 signup presents all mandatory controls on one screen',
  (tester) async {
   tester.view.physicalSize=const Size(430,1600);
   tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   await tester.pumpWidget(MaterialApp(
    home:ProfileForm(provider:'Phone',onSave:(_) async {})));
   await tester.pump();
   expect(find.byKey(const Key('waffra-register-single-page')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-name')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-gender-male')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-gender-female')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-phone')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-password')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-confirm-password')),findsOneWidget);
   expect(find.byKey(const Key('waffra-register-submit')),findsOneWidget);
   expect(find.text('البريد الإلكتروني'),findsNothing);
   expect(find.text('تاريخ الميلاد'),findsNothing);
  });

 test('M623 authentication and permissions precede verified Home reveal',(){
  final a=main.indexOf(' Widget _m623RootContent(BuildContext rootContext){');
  final b=main.indexOf(' @override Widget build(BuildContext context)=>MaterialApp(',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  final route=main.substring(a,b);
  // The original signed-out/biometric/permission stages stay mounted and
  // noninteractive once successfully completed, until genuine Home is ready.
  expect(route,contains('final needsLogin=account==null||showLogin||'));
  expect(route,contains('final firstConsent=!needsLogin&&autoSmsConsentPending&&'));
  expect(route,contains('_smsConsentAfterVerifiedSignIn;'));
  expect(route,contains('final needsGate=!needsLogin&&!firstConsent&&locked;'));
  expect(route,contains('final laterConsent=!needsLogin&&!firstConsent&&!needsGate&&autoSmsConsentPending;'));
  expect(route,contains('final canShowHome=!needsLogin&&!firstConsent&&!needsGate&&'));
  expect(route,contains('child:LoginScreen(onSave:saveUser,'));
  expect(route,contains('child:WaffraAutoSmsConsentPage('));
  expect(route,contains('child:WaffraMandatoryBiometricGate('));
  expect(route,contains('onSignOut:logout'));
  expect(route,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(route,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
  expect(route,contains('profile:account,'));
  expect(route,isNot(contains('onVerifiedReady:()=>_m623HomeLoaded(account!)')));
  expect(route,contains("key:ValueKey('home-\$_m627HomeSession')"));
  expect(route,contains('key:_m627HomeKey,'));
  expect(route,isNot(contains('CircularProgressIndicator(')));
 });

 test('M463 first clean install has only one account creation form',(){
  final login=main.substring(
   main.indexOf('class _LoginScreenState extends State<LoginScreen> {'),
   main.indexOf('class ProfileForm extends StatefulWidget {'));
  final registration=main.substring(
   main.indexOf(' Widget _phoneRegistrationForm(){'),
   main.indexOf(" @override Widget build(BuildContext context){\n  if(widget.initial==null&&widget.provider=='Phone')return _phoneRegistrationForm();"));
  expect(login,contains('if(!_registrationChecked){'));
  // A clean installation first shows the owner's explicit choice;
  // the one-page phone form appears only after Create Account is selected.
  expect(login,contains("if(_freshSignup&&_firstInstallChoice==null)return IntroScreen("));
  expect(login,contains("if(_freshSignup&&_firstInstallChoice=='create'){"));
  expect(login,contains("onBack:()=>setState(()=>_firstInstallChoice=null)"));
  expect(login,isNot(contains("if(_freshSignup)return ProfileForm(")));
  expect(login,contains('signInMode=oldUser?.provider.toLowerCase()==\'phone\';'));
  expect(login,contains("final hasSecureVerifier=await WaffraLocalPhoneCredentials"));
  expect(login,contains("final hasOldProfile=prefs.getString('waffra_profile')!=null;"));
  expect(login,contains("final hasLegacyVerifier=prefs.containsKey('waffra_local_password_hash')"));
  expect(login,contains('_freshSignup=raw==null&&!hasOldProfile&&!hasLegacyVerifier&&'));
  expect(registration,contains("Key('waffra-register-single-page')"));
  for(final key in const [
   'waffra-register-name','waffra-register-phone',
   'waffra-register-password','waffra-register-confirm-password',
   'waffra-register-submit',
  ]){expect(registration,contains("Key('$key')"));}
  // Gender keys are conditional expressions in the existing choice chips.
  expect(registration,contains("'waffra-register-gender-male'"));
  expect(registration,contains("'waffra-register-gender-female'"));
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
  // M602: first install/restored sessions require biometrics; normal verified
  // sign-out/sign-in does not ask for the same fingerprint twice.
  expect(save,contains('final freshSession=profile==null||showLogin;'));
  expect(save,contains('final ordinaryPhoneRelogin=profile==null&&showLogin&&'));
  expect(save,contains("(prefs.getBool('waffra_signed_out_explicitly')??false);"));
  expect(save,contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
  expect(save.indexOf('await _accountWriteAuthority.saveProfile('),
   lessThan(save.indexOf('if(freshSession)locked=!ordinaryPhoneRelogin;')));
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

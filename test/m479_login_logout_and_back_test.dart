import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

void main(){
 testWidgets('M479 welcome has separate Create Account and Sign In actions',
  (tester)async{
   var signups=0,logins=0;
   await tester.pumpWidget(MaterialApp(home:IntroScreen(
    onStart:()async{signups++;},onLogin:()async{logins++;})));
   expect(find.byKey(const Key('waffra-first-run-auth-choice')),findsOneWidget);
   await tester.tap(find.byKey(const Key('waffra-auth-choice-sign-in')));
   await tester.pump();
   expect(logins,1);expect(signups,0);
   await tester.tap(find.byKey(const Key('waffra-auth-choice-create')));
   await tester.pump();
   expect(logins,1);expect(signups,1);
 });

 test('M479 sign-in is minimal and Back returns to original auth choice',(){
   final s=readWaffraMainSourceForContracts();
   final login=s.substring(s.indexOf('class _LoginScreenState extends State<LoginScreen> {'),
     s.indexOf('class ProfileForm extends StatefulWidget {'));
   expect(login,contains("key:const Key('m479-login-back-to-choice')"));
   expect(login,contains("waffraIsEnglish?'Back':'عودة'"));
   expect(login,isNot(contains("waffraIsEnglish?'Create an account':'إنشاء حساب'")));
   expect(login,isNot(contains('مفيش حساب محلي موثّق')));
   expect(login,isNot(contains('restore its trusted backup first')));
   expect(login,contains('if(_showChoiceAfterBack)return IntroScreen('));
   expect(login,contains('if(_freshSignup)_firstInstallChoice=null;'));
   expect(login,contains('else _showChoiceAfterBack=true;'));
   expect(login,contains('if(_freshSignup&&_firstInstallChoice==null)return IntroScreen('));
   expect(login,contains("onStart:()async{if(mounted)setState(()=>_firstInstallChoice='create');}"));
   expect(login,contains("onLogin:()async{if(mounted)setState(()=>_firstInstallChoice='login');}"));
   // Navigating to the landing screen never writes or erases any profile,
   // SQLCipher account, biometric verifier, or financial data.
   final nav=login.substring(login.indexOf('if(_showChoiceAfterBack)return IntroScreen('),
    login.indexOf('if(_freshSignup&&_firstInstallChoice==null)return IntroScreen('));
   expect(nav,isNot(contains('saveProfile(')));
   expect(nav,isNot(contains('signOut(')));
   expect(nav,isNot(contains('WaffraLocalPhoneCredentials.register(')));
   expect(login,contains('if(registered!=null){'));
   expect(login,contains('chooseRegistration();'));
 });

 test('M545 logout is only Yes/No; never shows password recovery',(){
   final s=readWaffraMainSourceForContracts();
   final signout=s.substring(s.indexOf(' Future<void> logout()async {'),
     s.indexOf(' Future<void> setPin('));
   final login=s.substring(s.indexOf('class _LoginScreenState extends State<LoginScreen> {'),
     s.indexOf('class ProfileForm extends StatefulWidget {'));
   final account=s.substring(s.indexOf('m513-home-signout-confirmation')-500,
     s.indexOf('m513-home-signout-yes')+250);
   expect(account,contains('هل أنت متأكد من تسجيل الخروج؟'));
   expect(account,contains('m513-home-signout-no'));
   expect(account,contains('m513-home-signout-yes'));
   expect(signout,isNot(contains('_recoverMissingPhoneVerifier(')));
   expect(signout,isNot(contains('showDialog(')));
   expect(signout,isNot(contains('WaffraLocalPhoneCredentials.registerOrResume(')));
   expect(signout,isNot(contains('WaffraBiometrics.unlockMandatory()')));
   expect(s,isNot(contains('m478-missing-verifier-recovery')));
   expect(s,isNot(contains('استعادة بيانات الدخول مرة واحدة')));
   expect(signout,contains('stageSignOutRecoveryGrant(phone)'));
   expect(signout,contains('WaffraAutoSms.suspendForSignOut()'));
   expect(signout,contains('await _accountWriteAuthority.signOut();'));
   expect(signout.indexOf('stageSignOutRecoveryGrant(phone)'),
     lessThan(signout.indexOf('await _accountWriteAuthority.signOut();')));
   expect(login,contains('hasSignOutRecoveryGrant(enteredPhone)'));
   expect(login,contains('WaffraBiometrics.unlockMandatory()'));
   expect(login,contains('finishSignInRecoveryAfterBiometric('));
   expect(login.indexOf('WaffraBiometrics.unlockMandatory()'),
     lessThan(login.indexOf('finishSignInRecoveryAfterBiometric(')));
 });

 test('M478 malformed and foreign verifier never count as recoverable missing',(){
  expect(WaffraLocalPhoneCredentials.inspectStoredRecord(null,
   phone:'0501234567'),WaffraLocalCredentialProbe.missing);
  expect(WaffraLocalPhoneCredentials.inspectStoredRecord('invalid-json',
   phone:'0501234567'),WaffraLocalCredentialProbe.malformed);
 });
}

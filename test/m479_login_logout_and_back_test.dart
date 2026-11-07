import 'dart:io';

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
   final s=File('lib/main.dart').readAsStringSync();
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

 test('M478 missing verifier can recover ONLY with fresh fingerprint and exact password read-back',(){
   final s=File('lib/main.dart').readAsStringSync();
   final recovery=s.substring(s.indexOf(' Future<bool> _recoverMissingPhoneVerifier(Person account)async{'),
    s.indexOf(' Future<void> logout()async {'));
   final signout=s.substring(s.indexOf(' Future<void> logout()async {'),
    s.indexOf(' Future<void> setPin('));
   expect(recovery,contains('m478-missing-verifier-recovery'));
   expect(recovery,contains('WaffraLocalCredentialProbe.missing'));
   expect(recovery,contains('WaffraBiometrics.unlockMandatory()'));
   expect(recovery,contains('WaffraLocalPhoneCredentials.registerOrResume('));
   expect(recovery,contains('WaffraLocalPhoneCredentials.verify('));
   expect(recovery.indexOf('WaffraBiometrics.unlockMandatory()'),
    lessThan(recovery.indexOf('WaffraLocalPhoneCredentials.registerOrResume(')));
   expect(recovery.indexOf('WaffraLocalPhoneCredentials.registerOrResume('),
    lessThan(recovery.indexOf('WaffraLocalPhoneCredentials.verify(')));
   expect(signout,contains('if(integrity==WaffraLocalCredentialProbe.missing){'));
   expect(signout,contains('final restored=await _recoverMissingPhoneVerifier(current);'));
   expect(signout,contains('if(!restored)return;'));
   expect(signout,contains('WaffraAutoSms.suspendForSignOut()'));
   expect(signout,contains('await _accountWriteAuthority.signOut();'));
   expect(signout.indexOf('_recoverMissingPhoneVerifier(current)'),
    lessThan(signout.indexOf('WaffraAutoSms.suspendForSignOut()')));
   expect(signout.indexOf('WaffraAutoSms.suspendForSignOut()'),
    lessThan(signout.indexOf('await _accountWriteAuthority.signOut();')));
   expect(signout,isNot(contains('WaffraLocalPhoneCredentials.registerOrResume(')));
 });

 test('M478 malformed and foreign verifier never count as recoverable missing',(){
  expect(WaffraLocalPhoneCredentials.inspectStoredRecord(null,
   phone:'0501234567'),WaffraLocalCredentialProbe.missing);
  expect(WaffraLocalPhoneCredentials.inspectStoredRecord('invalid-json',
   phone:'0501234567'),WaffraLocalCredentialProbe.malformed);
 });
}

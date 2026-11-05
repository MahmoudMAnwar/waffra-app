import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 late String source;
 setUpAll(() => source=File('lib/main.dart').readAsStringSync());

 test('M463 first launch always offers login before Android access',(){
  final start=source.indexOf("(loading||!introDone)?const WaffraLaunchIntro():");
  final end=source.indexOf("HomeScreen(key:ValueKey(language)",start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final route=source.substring(start,end);
  final login=route.indexOf("profile==null||showLogin||");
  final permission=route.indexOf("autoSmsConsentPending?WaffraAutoSmsConsentPage(");
  final biometric=route.indexOf("locked?WaffraMandatoryBiometricGate(");
  expect(login,greaterThan(0));
  expect(permission,greaterThan(login));
  expect(biometric,greaterThan(permission));
 });

 test('M463 an old cached profile cannot trigger permission on cold start',(){
  final load=source.substring(
   source.indexOf(" Future<void> load()async {"),
   source.indexOf(" Future<void> finishSmsPermissionChoice()async{"));
  expect(load,contains("profile=u;"));
  expect(load,contains("autoSmsConsentPending=false;"));
  expect(load,contains("_smsConsentAfterExistingSessionUnlock=Platform.isAndroid&&u!=null&&"));
  expect(load,isNot(contains("autoSmsConsentPending=Platform.isAndroid&&u!=null&&")));
 });

 test('M463 new registration queues permission only after credential save',(){
  final save=source.substring(
   source.indexOf(" Future<void> saveUser(Person u)async"),
   source.indexOf(" Future<void> setUiCountry(String? iso)async"));
  final saved=save.indexOf("await _accountWriteAuthority.saveProfile(");
  final pending=save.indexOf("autoSmsConsentPending=true;");
  expect(saved,greaterThan(-1));
  expect(pending,greaterThan(saved));
  expect(save,contains("if(needsSmsAccessAfterRegistration){"));
 });

 test('M463 existing session unlock can resume one-time consent safely',(){
  final app=source.substring(
   source.indexOf("class _WaffraAppState extends State<WaffraApp>"),
   source.indexOf("class PinLockScreen extends StatefulWidget"));
  expect(
   "_smsConsentAfterExistingSessionUnlock".allMatches(app).length,
   greaterThanOrEqualTo(5));
  expect(app,contains("if(_smsConsentAfterExistingSessionUnlock){"));
  expect(app,contains("locked=false;"));
  expect(app,contains("autoSmsConsentPending=true;"));
  expect(app,contains("if(!await p.setBool(WaffraAutoSms.firstRunKey,true))"));
 });

 test('M463 fresh user opens a single complete registration page directly',(){
  final login=source.substring(
   source.indexOf('class _LoginScreenState extends State<LoginScreen>'),
   source.indexOf('class ProfileForm extends StatefulWidget'));
  final build=login.substring(login.indexOf(' @override Widget build(BuildContext context){'));
  final fresh=build.indexOf('if(registered==null)return ProfileForm(');
  final welcome=build.indexOf('return Scaffold(backgroundColor:forest');
  expect(fresh,greaterThan(0));
  expect(welcome,greaterThan(fresh));
  expect(build,contains("Key('waffra-initial-single-page-registration')"));
  final registration=source.substring(
   source.indexOf('Widget _phoneRegistrationForm(){'),
   source.indexOf(' @override Widget build(BuildContext context){',
    source.indexOf('Widget _phoneRegistrationForm(){')));
  for(final field in [
   'waffra-register-name','waffra-register-gender-male',
   'waffra-register-gender-female','waffra-register-phone',
   'waffra-register-password','waffra-register-confirm-password',
   'waffra-register-submit',
  ]) {
   expect(registration,contains(field));
  }
  expect(registration,contains("Key('waffra-register-single-page')"));
 });

 test('M463 existing Saudi phone user has one direct login view',(){
  final login=source.substring(
   source.indexOf('class _LoginScreenState extends State<LoginScreen>'),
   source.indexOf('class ProfileForm extends StatefulWidget'));
  expect(login,contains(
   "signInMode=existing!=null&&existing.provider.toLowerCase()=='phone';"));
  expect(login,contains('signInPhone.text=existing==null'));
  expect(login,contains('waffraMobileFieldError(signInPhone.text)'));
  expect(login,contains('WaffraLocalPhoneCredentials.verify('));
  expect(login,contains('controller:signInPassword'));
  expect(login,contains('if(registeredLoading)return const Scaffold('));
  expect(login,contains('registeredReadError=waffraIsEnglish?'));
 });

 test('M463 no new privacy permission is requested during loading',(){
  final load=source.substring(
   source.indexOf(" Future<void> load()async {"),
   source.indexOf(" Future<void> finishSmsPermissionChoice()async{"));
  expect(load,isNot(contains("WaffraAutoSms.optIn()")));
  expect(load,isNot(contains("requestNotificationPermission()")));
  expect(load,isNot(contains("requestAutoSmsPermission")));
 });
}

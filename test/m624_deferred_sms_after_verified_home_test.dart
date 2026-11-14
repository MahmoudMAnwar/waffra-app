import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// M624: post-login native SMS work may not steal the FIRST real Home frame.
/// A signed Android cold/warm profile trace is still required for speed claims.
void main() {
 final source=readWaffraMainSourceForContracts();
 final app=source.split('class _WaffraAppState extends State<WaffraApp>')[1]
  .split('class PinLockScreen extends StatefulWidget')[0];
 final userSave=app.split(' Future<void> saveUser(Person u)async {')[1]
  .split(' Future<void> setUiCountry(')[0];
 final logout=app.split(' Future<void> logout()async {')[1]
  .split(' bool _logoutInProgress=false;')[0];
 final root=app.split(' Widget _m623RootContent(BuildContext rootContext){')[1]
  .split(' @override Widget build(BuildContext context)=>MaterialApp(')[0];
 final startup=source.split(' Future<void> _loadFinanceSafely()async{')[1]
  .split(' Widget _financialRecoveryScreen()')[0];

 test('M624: saveUser never schedules SMS capture before verified Home',(){
  expect(userSave,isNot(contains('WaffraAutoSms.resumeAfterSignIn()')));
  expect(userSave,isNot(contains('unawaited(_refreshAutoSmsInbox(')));
  expect(app,contains('Future<bool> _m624ResumeSmsAfterRealHome(Person expectedOwner)async{'));
  expect(app,contains('final resumed=await WaffraAutoSms.resumeAfterSignIn();'));
  expect(root,contains('onVerifiedHomeSmsResume:()=>_m624ResumeSmsAfterRealHome(account)'));
 });

 test('M624: owner and consent gates must precede native resume',(){
  final resume=app.split(' Future<bool> _m624ResumeSmsAfterRealHome(Person expectedOwner)async{')[1]
   .split(' void _m623HomeLoaded(')[0];
  expect(resume,contains('identical(profile,expectedOwner)'));
  expect(resume,contains('!showLogin&&!locked&&!autoSmsConsentPending'));
  expect(resume,contains('!_logoutInProgress&&_m623HomeReady'));
  expect(resume.indexOf('if(!Platform.isAndroid||!ownerIsActive())return false;'),
   lessThan(resume.indexOf('WaffraAutoSms.resumeAfterSignIn()')));
  expect(resume,contains('if(resumed&&ownerIsActive())waffraAutoSmsUpdates.value++;'));
 });

 test('M624: logout serializes native capture and cannot re-enable on signout',(){
  expect(logout.indexOf('final pendingSmsResume=_m624SmsResumeInFlight;'),
   lessThan(logout.indexOf('WaffraAutoSms.suspendForSignOut()')));
  expect(logout,contains('if(pendingSmsResume!=null)await pendingSmsResume;'));
  expect(app,contains('_logoutInProgress=true;'));
  expect(app,contains('if(identical(_m624SmsResumeInFlight,running))'));
  expect(logout,contains('await _accountWriteAuthority.signOut();'));
 });

 test('M624: after-first-frame native work then sequential inbox review',(){
  expect(startup.indexOf('await load();'),
   lessThan(startup.indexOf('widget.onVerifiedReady?.call();')));
  expect(startup,contains('WidgetsBinding.instance.addPostFrameCallback'));
  expect(startup,contains('await Future<void>.delayed(const Duration(milliseconds:900));'));
  expect(startup,contains('final activeOwner=(await widget.onVerifiedHomeSmsResume?.call())??true;'));
  expect(startup,contains('if(!activeOwner||!_m630SmsSessionCurrent(startupEpoch))return;'));
  expect(source,contains('epoch==_m630HomeStartupEpoch;'));
  expect(source,contains('mounted&&ready&&widget.postAuthVisible&&'));
  expect(startup.indexOf('final activeOwner=(await widget.onVerifiedHomeSmsResume?.call())??true;'),
   lessThan(startup.indexOf('await _refreshAutoSmsInbox(importMonth:')));
 });

 test('M624: do not replace genuine complete finance Home with fake values',(){
  expect(root,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(root,contains('postAuthVisible:homeInteractive'));
  expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
  expect(root,isNot(contains('CircularProgressIndicator(')));
  expect(root,isNot(contains('بنفتح الرئيسية')));
  expect(source,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(source,contains('.timeout(const Duration(seconds:15));'));
  expect(source.indexOf('await (accountsLoading??_m467RefreshHomeAccounts())'),
   lessThan(source.indexOf('setState(()=>ready=true);')));
  expect(startup,contains('_financeLoadFailure=waffraIsEnglish?'));
 });
}

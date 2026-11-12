import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final source=File('lib/main.dart').readAsStringSync();
 final root=source.split(' Widget _m623RootContent(BuildContext rootContext){')[1]
  .split(' @override Widget build(BuildContext context)=>MaterialApp(')[0];
 final homeLoader=source.split(' Future<void> _loadFinanceSafely()async{')[1]
  .split(' Widget _financialRecoveryScreen()')[0];
 final shell=source.split(' @override Widget build(BuildContext context)=>PopScope(')[1]
  .split('  // A fixed 58x58 FAB:')[0];

 test('M623 keeps prior authenticated UI until one complete verified Home',(){
  expect(root,contains('final canShowHome=!needsLogin&&!firstConsent&&!needsGate&&'));
  expect(root,contains('final canMountHome=canShowHome||'));
  expect(root,contains('_m663OnboardingHomePreload&&!needsLogin&&!needsCountry'));
  expect(root,contains('final beforeReady=canShowHome&&!_m623HomeReady;'));
  expect(root,contains("beforeReady&&_m623RetainedStage=='login'"));
  expect(root,contains("beforeReady&&_m623RetainedStage=='biometric'"));
  expect(root,contains("beforeReady&&_m623RetainedStage=='consent'"));
  expect(root,contains('child:IgnorePointer(ignoring:!needsLogin,'));
  expect(root,contains('child:IgnorePointer(ignoring:!needsGate,'));
  expect(root,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(root,contains("key:ValueKey('home-\$_m627HomeSession')"));
  expect(root,contains('key:_m627HomeKey,'));
  expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
  expect(root,contains('profile:account,'));
  expect(root,isNot(contains('onVerifiedReady:()=>_m623HomeLoaded(account!)')));
  expect(root,isNot(contains('CircularProgressIndicator(')));
  expect(root,isNot(contains('SizedBox.shrink(')));
  expect(root,isNot(contains('بنفتح الرئيسية')));
 });

 test('M623 authenticated Home transition cannot expose unverified money',(){
  expect(source,contains('if(mounted)widget.onVerifiedReady?.call();'));
  expect(homeLoader.indexOf('await load();'),
   lessThan(homeLoader.indexOf('widget.onVerifiedReady?.call();')));
  expect(homeLoader,contains('_financeLoadFailure=waffraIsEnglish?'));
  expect(shell,contains('child:!ready&&_financeLoadFailure==null?'));
  expect(shell,contains('const SizedBox.shrink():Stack(children:[Scaffold('));
  // The Home internal placeholder is never visible because the app root
  // keeps the authenticated stage on top and mounts Home Offstage.
  expect(root,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(source,contains('_m623HomeReady=false;_m623RetainedStage=null;'));
  expect(source,contains("current.provider!=expectedOwner.provider"));
  expect(source,contains("current.phone!=expectedOwner.phone"));
 });

 test('M623 background SMS runs only after the complete Home frame',(){
  expect(homeLoader.indexOf('widget.onVerifiedReady?.call();'),
   lessThan(homeLoader.indexOf('WidgetsBinding.instance.addPostFrameCallback')));
  expect(homeLoader,contains('Duration(milliseconds:900)'));
  expect(homeLoader,contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
  expect(source,contains('mounted&&ready&&widget.postAuthVisible&&'));
  expect(source,contains('epoch==_m630HomeStartupEpoch;'));
  expect(homeLoader,contains('await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete)'));
 });
}

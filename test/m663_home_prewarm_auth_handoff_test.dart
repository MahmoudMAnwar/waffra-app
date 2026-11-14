import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
 final app=readWaffraMainSourceForContracts();
 final root=app.substring(
  app.indexOf('class _WaffraAppState extends State<WaffraApp>'),
  app.indexOf('class HomeScreen extends StatefulWidget'));
 final route=root.substring(root.indexOf('Widget _m623RootContent('),
  root.indexOf('@override Widget build(BuildContext context)=>MaterialApp('));
 final home=app.substring(app.indexOf('class _HomeScreenState extends'),
  app.indexOf('Widget compactTransaction(MoneyEntry entry)'));

 test('M663 only verified first registration preassembles hidden Home',(){
  expect(root,contains('_m663OnboardingHomePreload=needsSmsAccessAfterRegistration&&'));
  expect(root,contains('!ordinaryPhoneRelogin;'));
  expect(root,contains('await _accountWriteAuthority.saveProfile('));
  expect(root.indexOf('await _accountWriteAuthority.saveProfile('),
   lessThan(root.indexOf('_m663OnboardingHomePreload=needsSmsAccessAfterRegistration&&')));
  expect(route,contains('final canShowHome=!needsLogin&&!firstConsent&&!needsGate&&'));
  expect(route,contains('_m663OnboardingHomePreload&&!needsLogin&&!needsCountry'));
  expect(route,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(route,contains('child:TickerMode(enabled:homeInteractive,child:HomeScreen('));
  expect(route,contains('postAuthVisible:homeInteractive,'));
  expect(app,contains('this.postAuthVisible=true, // Standalone Home remains interactive; root overrides for preload.'));

  expect(route,contains('child:WaffraMandatoryBiometricGate('));
  expect(route,contains('child:WaffraAutoSmsConsentPage('));
  expect(route,contains('child:IgnorePointer(ignoring:!needsGate,'));
  expect(route,contains('child:IgnorePointer(ignoring:!firstConsent&&!laterConsent,'));
 });

 test('M663 hidden finance readiness never bypasses biometric or consent',(){
  final loaded=root.substring(root.indexOf('void _m623HomeLoaded('),
   root.indexOf("String appearance='light';"));
  expect(loaded,contains('_m663OnboardingHomePreload&&(locked||autoSmsConsentPending)'));
  expect(loaded,contains('_m663PreloadedFinanceReady=true;'));
  expect(loaded,contains('if(locked||autoSmsConsentPending)return;'));
  final reveal=root.substring(root.indexOf('void _m663RevealPreloadedHome(){'),
   root.indexOf('String? _m623RetainedStage;'));
  expect(reveal,contains('if(!mounted||locked||showLogin||autoSmsConsentPending||'));
  expect(reveal,contains('if(_m663PreloadedFinanceReady)'));
  expect(reveal,contains('_m623HomeReady=true;'));
  expect(root,contains('_m663RevealPreloadedHome();'));
  expect(route,contains("beforeReady&&_m623RetainedStage=='biometric'"));
  expect(root,contains('_m663OnboardingHomePreload=false;_m663PreloadedFinanceReady=false;'));
 });

 test('M663 real finance must be verified before first Home, even on fresh install',(){
  final load=home.substring(home.indexOf('Future<void> load()async {'),
   home.indexOf('Future<void> _refreshWidget()async{'));
  expect(load,contains('WaffraFreshHomeCatalogRecovery.load('));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(load.indexOf('financeView.requireIntegrity();'),
   lessThan(load.indexOf('setState(()=>ready=true);')));
  expect(load,isNot(contains('waffraAvailableCash(entries,goals)')));
  expect(root,isNot(contains('_m663CachedBankBalance')));
 });

 test('M663 optional SMS, widgets and notifications await interactive first frame',(){
  expect(home,contains('final Completer<void> _m663FirstInteractiveFrame=Completer<void>();'));
  expect(home,contains('Future<bool> _m663AwaitVisible(int epoch)async{'));
  expect(home,contains('if(widget.postAuthVisible&&!oldWidget.postAuthVisible&&'));
  expect(home,contains('_m663FirstInteractiveFrame.complete();'));
  expect(home,contains('widget.postAuthVisible&&'));
  final startup=home.substring(home.indexOf('Future<void> _loadFinanceSafely()async{'),
   home.indexOf('Widget _financialRecoveryScreen()=>'));
  expect(startup,contains('if(!await _m663AwaitVisible(startupEpoch)||'));
  expect(startup.indexOf('if(!await _m663AwaitVisible(startupEpoch)||'),
   lessThan(startup.indexOf('await widget.onVerifiedHomeSmsResume?.call()')));
  expect(loadOptional(home),contains('if(!await _m663AwaitVisible(startupEpoch)||'));
  expect(home,contains('if(!mounted||!ready||!widget.postAuthVisible||'));
  // M664: the back handler is later in the same Home state class, after
  // compactTransaction(), which terminates the source window above.
  final back=app.substring(app.indexOf(' bool _consumeHomeBack(){'),
   app.indexOf(' @override Widget build(BuildContext context)=>PopScope(',
    app.indexOf(' bool _consumeHomeBack(){')));
  expect(back,contains('if(!mounted||!widget.postAuthVisible)return false;'));
  expect(home,contains('epoch==_m630HomeStartupEpoch&&!_m627ClosingSession;'));
  expect(home,contains('if(!_m663FirstInteractiveFrame.isCompleted)_m663FirstInteractiveFrame.complete();'));
 });

 test('M663 explicit logout closes bound Home and invalidates preload',(){
  final logout=root.substring(root.indexOf('Future<void> logout()async {'),
   root.indexOf('bool _logoutInProgress=false;'));
  expect(logout,contains('await closingHome._m627CloseForLogout();'));
  expect(logout,contains('await _accountWriteAuthority.signOut();'));
  expect(logout,contains('_m663OnboardingHomePreload=false;_m663PreloadedFinanceReady=false;'));
  expect(logout,contains('_m627HomeSession++;'));
  expect(root,contains('locked=!ordinaryPhoneRelogin;'));
  expect(root,contains('_m631StartFinancePrewarm(u);'));
  expect(home,contains('await binding.close();'));
 });
}

String loadOptional(String home){
 final start=home.indexOf('Future<void> load()async {');
 final end=home.indexOf('Future<void> _refreshWidget()async{',start);
 return home.substring(start,end);
}

import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// M631: source-level safety contract. CI cannot certify physical Android
/// first-frame timing; profile APK traces and two-device data QA are required.
void main() {
 final src=readWaffraMainSourceForContracts();
 final app=src.split('class _WaffraAppState extends State<WaffraApp>')[1]
   .split('class PinLockScreen extends StatefulWidget')[0];
 final home=src.split('class _HomeScreenState extends State<HomeScreen>')[1];
 final startup=home.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
 final load=home.split(' Future<void> load()async {')[1]
   .split(' Future<void> _refreshWidget()async{')[0];
 final save=app.split(' Future<void> saveUser(Person u)async {')[1]
   .split(' Future<void> setUiCountry(')[0];
 final root=app.split(' Widget _m623RootContent(BuildContext rootContext){')[1]
   .split(' @override Widget build(BuildContext context)=>MaterialApp(')[0];
 final logout=app.split(' Future<void> logout()async {')[1]
   .split(' bool _logoutInProgress=false;')[0];

 test('verified phone profile persistence precedes BIND-only background start',(){
  expect(save.indexOf('await _accountWriteAuthority.saveProfile('),
    lessThan(save.indexOf('_m631StartFinancePrewarm(u);')));
  expect(save,contains('final shouldPrewarmNewSession=profile==null||showLogin;'));
  expect(save,contains('if(mounted&&shouldPrewarmNewSession)_m631StartFinancePrewarm(u);'));
  expect(app,contains('if(u!=null)_m631StartFinancePrewarm(u);'));
  expect(app,contains('deferInitialDashboardRead:true,'));
  expect(app,contains('startupRoute:WaffraFinanceRoute.appStartup'));
  expect(app,contains('!identical(profile,owner)'));
  expect(app,contains('_m627HomeSession!=session'));
  expect(app,contains('_m631PrewarmBinding=()async{'));
  expect(app,isNot(contains('unawaited(_m467RefreshHomeAccounts().then(')));
 });

 test('prewarm is claimed only by exact active profile/session, while visibility requires biometric',(){
  expect(app,contains('Future<WaffraProductionFinanceAuthorityBinding?>? _m631ClaimFinancePrewarm('));
  expect(app,contains('_m631PrewarmSession!=_m627HomeSession'));
  expect(app,contains('_m631PrewarmClaimed=true;'));
  expect(root,contains('if(canMountHome)KeyedSubtree('));
  expect(root,contains('prewarmedFinanceBinding:_m631ClaimFinancePrewarm(account)'));
  expect(root,contains('child:Offstage(offstage:!homeInteractive,'));
  expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
  expect(root,contains('final canShowHome=!needsLogin&&!firstConsent&&!needsGate&&'));
  expect(root,contains('final canMountHome=canShowHome||'));
  expect(root,contains('postAuthVisible:homeInteractive'));
  expect(app,isNot(contains('final canMountHome=profile!=null;')));
 });

 test('Home reuses warmed binding or retries secure original binder',(){
  final bind=home.split(' Future<void> _bindFinanceSource()async{')[1]
    .split(' // M627: sign-out closes the Home-owned binding')[0];
  expect(bind,contains('final pendingWarm=_m631PrewarmConsumed?null:widget.prewarmedFinanceBinding;'));
  expect(bind,contains('_m631PrewarmConsumed=true;'));
  expect(bind,contains('final warmed=await pendingWarm;'));
  expect(home,contains('bool _m631PrewarmConsumed=false;'));
  expect(bind,contains('final binding=warmed??await WaffraProductionFinanceAuthorityBinding.bind('));
  expect(bind,contains('deferInitialDashboardRead:true,'));
  expect(bind,contains('if(!mounted){await binding.close();'));
  expect(bind,contains('_financeBinding=binding;'));
  expect(bind,contains('_financeAuthority=binding.authority;'));
  expect(home,contains('final pending=_financeBindingFuture??=_bindFinanceSource();'));
 });

 test('logout drains Home-owned DB or closes unused prewarm and rotates identity',(){
  expect(logout,contains('if(closingHome!=null){'));
  expect(logout,contains('await closingHome._m627CloseForLogout();'));
  expect(logout,contains('await _m631CloseUnusedPrewarm();'));
  expect(logout,contains('await _m631CloseUnusedPrewarm(includeClaimed:true);'));
  expect(logout.indexOf('await Future.wait<void>(['),
    lessThan(logout.indexOf('await _accountWriteAuthority.signOut();')));
  expect(logout,contains('_m627HomeSession++;'));
  expect(logout,contains('_m631PrewarmBinding=null;_m631PrewarmOwner=null;'));
  expect(app,contains('if(binding!=null)await binding.close();'));
  expect(app,contains('includeClaimed:_m627HomeKey.currentState==null'));
  expect(home,contains('await _financialWriteQueue.drain().timeout('));
 });

 test('actual verified financial balances still gate FIRST visible Home',(){
  expect(startup,contains('await load();'));
  expect(startup,contains('widget.onVerifiedReady?.call();'));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(load,contains('.timeout(const Duration(seconds:15));'));
  expect(load,contains('if(!_m468VerifiedAccountsLoaded){'));
  expect(load.indexOf('await (accountsLoading??_m467RefreshHomeAccounts())'),
   lessThan(load.indexOf('setState(()=>ready=true);')));
  expect(load,isNot(contains('unawaited(_m467RefreshHomeAccounts().then(')));
  expect(src,isNot(contains('Widget _m622ImmediateHomeSurface()=>')));
 });

 test('optional widget/reminder after ready and SMS only after real Home',(){
  expect(load.indexOf('setState(()=>ready=true);'),
    lessThan(load.indexOf('Duration(milliseconds:400)')));
  expect(load,contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
  expect(home,contains('mounted&&ready&&widget.postAuthVisible&&'));
  expect(home,contains('epoch==_m630HomeStartupEpoch;'));
  expect(load,contains('_m630PostFrameFinanceWork=postFrameFinance;'));
  expect(load,contains('if(!verifiedEncryptedStartup)await applyRecurring();'));
  expect(load,isNot(contains('unawaited(_refreshWidget());')));
  expect(load,isNot(contains('unawaited(syncRecurringReminders());')));
  for(final phrase in <String>[
   '_receiveWidgetAction();', 'await _refreshWidget();',
   'await syncRecurringReminders();',
  ]){expect(load,contains(phrase),reason:phrase);}
  expect(startup,contains('Duration(milliseconds:900)'));
  expect(startup,contains('await widget.onVerifiedHomeSmsResume?.call()'));
  expect(startup.indexOf('widget.onVerifiedReady?.call();'),
    lessThan(startup.indexOf('await widget.onVerifiedHomeSmsResume?.call()')));
 });
}

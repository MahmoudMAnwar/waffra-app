import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M630 / Issue #542: independent work must not steal the first verified
/// authenticated Home frame or run against a signed-out finance session.
/// These are source/ordering regressions, not physical-device benchmarks.
void main() {
 final app=File('lib/main.dart').readAsStringSync();
 final home=app.split('class _HomeScreenState extends State<HomeScreen>')[1];
 final root=app.split('class _WaffraAppState extends State<WaffraApp>')[1]
  .split('class PinLockScreen extends StatefulWidget')[0];
 final initial=home.split(' Future<void> _loadFinanceSafely()async{')[1]
  .split(' Widget _financialRecoveryScreen()')[0];
 final load=home.split(' Future<void> load()async {')[1]
  .split(' Future<void> _refreshWidget()async{')[0];
 final close=home.split(' Future<void> _m627CloseForLogout()async{')[1]
  .split(' void _m627AbortFailedLogout()')[0];

 test('first Home requires the same real integrity and accounts before reveal',(){
  expect(load,contains('await _ensureFinanceBound();'));
  expect(load,contains('WaffraFreshHomeCatalogRecovery.load('));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(load,contains('.timeout(const Duration(seconds:15));'));
  expect(load.indexOf('if(!_m468VerifiedAccountsLoaded){'),
   lessThan(load.indexOf('setState(()=>ready=true);')));
  expect(initial.indexOf('await load();'),
   lessThan(initial.indexOf('widget.onVerifiedReady?.call();')));
  expect(root,contains('child:Offstage(offstage:!_m623HomeReady,'));
  expect(root,contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
 });

 test('no widget, SMS, reminders or tutorial run inside first load frame',(){
  expect(load,isNot(contains('unawaited(_refreshWidget());')));
  expect(load,isNot(contains('unawaited(syncRecurringReminders());')));
  expect(load,isNot(contains('_tourGlow.repeat(reverse:true);')));
  expect(load,contains('_m630TourPending='));
  expect(initial,contains('WidgetsBinding.instance.addPostFrameCallback'));
  expect(initial.indexOf('widget.onVerifiedReady?.call();'),
   lessThan(initial.indexOf('Duration(milliseconds:900)')));
  expect(initial.indexOf('Duration(milliseconds:900)'),
   lessThan(initial.indexOf('await _refreshWidget();')));
  expect(initial.indexOf('await _refreshWidget();'),
   lessThan(initial.indexOf('await syncRecurringReminders();')));
  expect(initial.indexOf('await syncRecurringReminders();'),
   lessThan(initial.indexOf('await widget.onVerifiedHomeSmsResume?.call()')));
  expect(initial.indexOf('await widget.onVerifiedHomeSmsResume?.call()'),
   lessThan(initial.indexOf('await _refreshAutoSmsInbox(importMonth:')));
  expect(initial.indexOf('await _refreshAutoSmsInbox(importMonth:'),
   lessThan(initial.indexOf('_tourGlow.repeat(reverse:true);')));
 });

 test('logout and retry invalidate old tasks; SQLCipher waits for widget',(){
  expect(home,contains('int _m630HomeStartupEpoch=0;'));
  expect(home,contains('Future<void>? _m630PostFrameFinanceWork;'));
  expect(initial,contains('final startupEpoch=++_m630HomeStartupEpoch;'));
  expect(initial,contains('startupEpoch!=_m630HomeStartupEpoch'));
  expect(initial,contains('if(_m627ClosingSession||startupEpoch!=_m630HomeStartupEpoch)return;'));
  expect(initial,contains('_m630PostFrameFinanceWork=startupFinance;'));
  expect(initial,contains('identical(_m630PostFrameFinanceWork,startupFinance)'));
  expect(close,contains('_m630HomeStartupEpoch++;'));
  expect(close,contains('_m630TourPending=false;'));
  expect(close,contains('final startupFinance=_m630PostFrameFinanceWork;'));
  expect(close,contains('await startupFinance.timeout(const Duration(seconds:20));'));
  expect(close.indexOf('await startupFinance.timeout('),
   lessThan(close.indexOf('if(binding!=null)await binding.close();')));
  expect(root,contains('await WaffraAutoSms.suspendForSignOut().timeout('));
  expect(root,contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
  expect(root,contains('_m627HomeSession++;'));
  expect(initial,contains('_financeLoadFailure=waffraIsEnglish?'));
 });
}

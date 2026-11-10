import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M629 / #540: fast pull mechanics must speed up independent preparation
/// while preserving password, SQLCipher, account witness and owner checks.
void main(){
 final app=File('lib/main.dart').readAsStringSync();
 final login=app.split(' Future<void> _signIn()async{')[1]
   .split(' String get maskedLastPhone{')[0];
 final root=app.split('class _WaffraAppState extends State<WaffraApp>')[1]
   .split('class PinLockScreen extends StatefulWidget')[0];
 final logout=root.split(' Future<void> logout()async {')[1]
   .split(' Future<void> setPin(')[0];
 final home=app.split('class _HomeScreenState extends State<HomeScreen>')[1];
 final load=home.split(' Future<void> load()async {')[1]
   .split(' Future<void> _refreshWidget()async{')[0];
 final pull=home.split(' Future<void> _refreshAndSettle(')[1]
   .split(' Future<void> load()async {')[0];

 test('M629 preserves verified pull refresh no-op and single flight',(){
  expect(pull,contains('final pending=_m474PullRefreshInFlight;'));
  expect(pull,contains('if(pending!=null)return pending;'));
  expect(pull,contains('encryptedCurrent.generation==encryptedPrevious.generation'));
  expect(pull,contains('encryptedCurrent.digest==encryptedPrevious.digest'));
  expect(pull,contains('current.widgetRevision==previous?.widgetRevision'));
  expect(pull,contains('await WaffraLargeJsonDecode.parse(ledger)'));
 });

 test('M629 starts independent Home preferences while vault binds',(){
  expect(load,contains('final preferencesLoading=SharedPreferences.getInstance();'));
  expect(load,contains('await _ensureFinanceBound();'));
  expect(load,contains('final p=await preferencesLoading;'));
  expect(load.indexOf('final preferencesLoading='),
   lessThan(load.indexOf('await _ensureFinanceBound();')));
  expect(load.indexOf('await _ensureFinanceBound();'),
   lessThan(load.indexOf('final p=await preferencesLoading;')));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(load,contains('.timeout(const Duration(seconds:15));'));
  expect(load.indexOf('if(!_m468VerifiedAccountsLoaded){'),
   lessThan(load.indexOf('setState(()=>ready=true);')));
 });

 test('M629 sign-in parallel prep still verifies actual password',(){
  expect(login,contains('final prefsLoading=SharedPreferences.getInstance();'));
  expect(login,contains(
   'final secureInspectionLoading=WaffraLocalPhoneCredentials.readForSignIn();'));
  expect(login.indexOf('final prefsLoading='),
   lessThan(login.indexOf('final prefs=await prefsLoading;')));
  expect(login.indexOf('final secureInspectionLoading='),
   lessThan(login.indexOf('var inspection=await secureInspectionLoading;')));
  expect(login,contains('WaffraLocalPhoneCredentials.probeForPhone('));
  expect(login,contains('WaffraLocalPhoneCredentials.verify('));
  expect(login.indexOf('WaffraLocalPhoneCredentials.verify('),
   lessThan(login.indexOf('await widget.onVerifiedPasswordSave(verifiedAccount);')));
  expect(login,contains('if(!match){'));
 });

 test('M629 logout awaits BOTH independent teardown tasks before signout',(){
  expect(logout,contains('await WaffraAutoSms.suspendForSignOut().timeout('));
  expect(logout,contains('await Future.wait<void>(['));
  expect(logout,contains(
   'WaffraOnDeviceQwen.shared.dispose().timeout(const Duration(seconds:12))'));
  expect(logout,contains('if(closingHome!=null)await closingHome._m627CloseForLogout();'));
  expect(logout,contains('closeHomeFinance(),'));
  expect(logout.indexOf('await Future.wait<void>(['),
   lessThan(logout.indexOf('await _accountWriteAuthority.signOut();')));
  expect(logout.indexOf('await _accountWriteAuthority.signOut();'),
   lessThan(logout.indexOf('profile=null;showLogin=true;locked=true;')));
  expect(logout,contains('}catch(error){'));
  expect(logout,contains('_m627AbortFailedLogout()'));
  expect(root,contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
 });

 test('M629 does not move SMS scanning before verified Home',(){
  final safe=home.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
  expect(safe,contains('await load();'));
  expect(safe.indexOf('widget.onVerifiedReady?.call();'),
   lessThan(safe.indexOf('await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete)')));
  expect(safe,contains('await widget.onVerifiedHomeSmsResume?.call()'));
 });
}

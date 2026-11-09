import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M470 #1 all signout entry points route to single safe logout',(){
  final home=File('lib/main.dart').readAsStringSync();
  final start=home.indexOf(' Future<void> logout()async {');
  final end=home.indexOf(' Future<void> setPin(',start);
  expect(start,greaterThan(0));
  final action=home.substring(start,end);
  expect(home,contains('onSignOut:logout'));
  expect(home,contains('onLogout:logout'));
  expect(action,contains('if(_logoutInProgress)return;'));
  expect(action,contains('WaffraAutoSms.suspendForSignOut()'));
  expect(action,contains('await _accountWriteAuthority.signOut();'));
  expect(action,contains('}catch(error){'));
  expect(action,contains('تعذر تسجيل الخروج بأمان'));
  expect(action,contains('}finally{'));
  expect(action,contains('_logoutInProgress=false;'));
  expect(action.indexOf('WaffraAutoSms.suspendForSignOut()'),
    lessThan(action.indexOf('_accountWriteAuthority.signOut()')));
  expect(action.indexOf('_accountWriteAuthority.signOut()'),
    lessThan(action.indexOf('profile=null;showLogin=true')));
 });

 test('M470 #2 unchanged verified refresh avoids reconstructing whole ledger',(){
  final home=File('lib/main.dart').readAsStringSync();
  final start=home.indexOf(' Future<void> _refreshFromVerifiedFinance()async {');
  final end=home.indexOf(' Future<void> load()async {',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final refresh=home.substring(start,end);
  expect(refresh,contains('await _financialWriteQueue.drain();'));
  expect(refresh,contains('view.requireIntegrity();'));
  expect(refresh,contains('WaffraRuntimeFinanceBackend.verifiedEncrypted'));
  expect(refresh,contains('encryptedCurrent.generation==encryptedPrevious.generation'));
  expect(refresh,contains('encryptedCurrent.digest==encryptedPrevious.digest'));
  expect(refresh,contains('current.widgetRevision==previous?.widgetRevision'));
  expect(refresh.indexOf('encryptedCurrent.generation==encryptedPrevious.generation'),
    lessThan(refresh.indexOf('await _m593BuildVerifiedEntries(')));
  expect(refresh,contains('final refreshSource=WaffraVerifiedPullRefreshSource.fromAuthority(current);'));
  expect(refresh,contains('final nextEntries=await _m593BuildVerifiedEntries('));
  expect(refresh,contains('(await WaffraLargeJsonDecode.parse(ledger)) as List)'));
  expect(refresh,contains('if(current.source==WaffraRuntimeFinanceBackend.guardedLegacy)'));
  expect(refresh,contains('setState((){'));
 });
}

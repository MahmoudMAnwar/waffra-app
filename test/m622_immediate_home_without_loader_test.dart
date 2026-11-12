import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final source=File('lib/main.dart').readAsStringSync();

 test('M622 never renders fake balance or loading screen while verifying vault',(){
  final scaffold=source.split(' @override Widget build(BuildContext context)=>PopScope(')[1]
   .split('  // A fixed 58x58 FAB:')[0];
  expect(scaffold,contains('child:!ready&&_financeLoadFailure==null?'));
  expect(scaffold,contains('const SizedBox.shrink():Stack(children:[Scaffold('));
  expect(scaffold,contains('Stack(clipBehavior:Clip.none,children:[GestureDetector('));
  expect(scaffold,contains('duration:tab==0&&!accountOpened?Duration.zero:'));
  expect(source,isNot(contains('Widget _m622ImmediateHomeSurface()=>')));
  expect(source,isNot(contains("'بنفتح الرئيسية…'")));
  expect(source,isNot(contains("'Opening your dashboard…'")));
  expect(source,isNot(contains("const Text('••••'")));
  expect(scaffold,isNot(contains('!ready?RepaintBoundary(')));
  expect(scaffold,isNot(contains('!ready?const Center(child:CircularProgressIndicator(')));
 });

 test('M622 entire real Home values come from one completed verified load',(){
  final startup=source.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
  final load=source.split(' Future<void> load()async {').last
   .split(' // Home reloading an encrypted ledger')[0];
  final dashboard=source.split(' Widget dashboard(){')[1]
   .split(' Widget _currentTabContents()')[0];
  expect(startup,contains('await load();'));
  expect(load,contains('await _ensureFinanceBound();'));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('setState(()=>ready=true);'));
  // Verified financial account balances must not update in a second frame.
  expect(load,contains('final Future<void>? accountsLoading=verifiedEncryptedStartup?'));
  expect(load,contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
  expect(load,contains('.timeout(const Duration(seconds:15));'));
  expect(load,contains('}on TimeoutException{'));
  expect(load,contains('_m627AccountEpoch++;'));
  expect(load,contains('if(!_m468VerifiedAccountsLoaded){'));
  expect(load.indexOf('await (accountsLoading??_m467RefreshHomeAccounts())'),
   lessThan(load.indexOf('setState(()=>ready=true);')));
  expect(startup,isNot(contains('unawaited(_m467RefreshHomeAccounts());')));
  expect(dashboard,contains('final scopedEntries=_m467ScopedEntries().toList();'));
  expect(dashboard,contains('balance:_m467ShownBalance()'));
  expect(source,contains('floatingActionButton:!ready||accountOpened||tab==2?null:'));
 });

 test('M622 SMS scan is deferred until after verified Home frame',(){
  final startup=source.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
  expect(startup.indexOf('await load();'),
   lessThan(startup.indexOf('WidgetsBinding.instance.addPostFrameCallback')));
  expect(startup.indexOf('WidgetsBinding.instance.addPostFrameCallback'),
   lessThan(startup.indexOf('await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete)')));
  expect(startup,contains('Duration(milliseconds:900)'));
  expect(startup,contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
  expect(source,contains('mounted&&ready&&widget.postAuthVisible&&'));
  expect(source,contains('epoch==_m630HomeStartupEpoch;'));
 });
}

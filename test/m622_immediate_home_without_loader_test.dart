import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
 final source=File('lib/main.dart').readAsStringSync();

 test('M622 first Home paints approved sections without loading dialog',(){
  final unverified=source.split(' Widget _m622ImmediateHomeSurface()=>')[1]
   .split(' @override Widget build(BuildContext context)=>PopScope(')[0];
  final scaffold=source.split(' @override Widget build(BuildContext context)=>PopScope(')[1]
   .split('  // A fixed 58x58 FAB:')[0];
  expect(scaffold,contains('!ready?_m622ImmediateHomeSurface():'));
  expect(unverified,contains("key:const Key('m622-immediate-home-surface')"));
  expect(unverified,contains('WaffraPageHero('));
  expect(unverified,contains("waffraIsEnglish?'Total balance':'إجمالي الرصيد'"));
  expect(unverified,contains("const Text('••••'"));
  expect(unverified,contains('IgnorePointer('));
  expect(unverified,isNot(contains('CircularProgressIndicator(')));
  expect(unverified,isNot(contains('WaffraAutoSms.notifyCommitted(')));
  expect(unverified,isNot(contains('entries.add(')));
  expect(unverified,isNot(contains('waffraAvailableCash(')));
  expect(source,isNot(contains("'بنفتح الرئيسية…'")));
  expect(source,isNot(contains("'Opening your dashboard…'")));
  expect(scaffold,isNot(contains('!ready?RepaintBoundary(')));
 });

 test('M622 encryption validation still gates balances and finance actions',(){
  final loader=source.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
  final load=source.split(' Future<void> load()async {').last
   .split(' // Home reloading an encrypted ledger')[0];
  expect(loader,contains('setState((){ready=false;_financeLoadFailure=null;});'));
  expect(loader,contains('await load();'));
  expect(loader,contains('ready=false;'));
  expect(load,contains('await _ensureFinanceBound();'));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('setState(()=>ready=true);'));
  expect(source,contains('floatingActionButton:!ready||accountOpened||tab==2?null:'));
 });

 test('M622 actual SMS scan stays after first verified Home frame',(){
  final loader=source.split(' Future<void> _loadFinanceSafely()async{')[1]
   .split(' Widget _financialRecoveryScreen()')[0];
  final paints=loader.indexOf('WidgetsBinding.instance.addPostFrameCallback');
  final scan=loader.indexOf('await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete)');
  expect(paints,greaterThan(0));
  expect(scan,greaterThan(paints));
  expect(loader,contains('Duration(milliseconds:900)'));
  expect(loader,contains('if(!mounted||!ready||_financeLoadFailure!=null)return;'));
 });
}

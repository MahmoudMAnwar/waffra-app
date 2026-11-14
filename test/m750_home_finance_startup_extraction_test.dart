import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M750 actual Home finance startup reader registered once without changing money writer',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_finance_startup.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_finance_startup.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeFinanceStartup on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> load()async {\n  final financeClock=kProfileMode?')));
  for(final witness in <String>[
    ' Future<void> load()async {',
    'final startupEpoch=_m630HomeStartupEpoch;',
    'await _ensureFinanceBound();',
    'WaffraFreshHomeCatalogRecovery.load(',
    '_m684InvalidatePeriodRead();',
    'verifiedEncryptedStartup',
    '_lastFinanceAuthorityRead',
    '_m467RefreshHomeAccounts()',
    'WAFFRA_HOME_LOAD_STEP',
    'WaffraFinanceRoute.categoryCreateEditDeleteRestore',
  ]){
    expect(part,contains(witness),reason:witness);
  }
 });
 test('M750 old startup and finance contracts inspect real original method',(){
  final restored=readWaffraMainSourceForContracts();
  final pos=restored.indexOf(' Future<void> load()async {\n  final financeClock=kProfileMode?');
  final end=restored.indexOf(' Future<void> _refreshWidget()async{',pos);
  final part=File('lib/waffra_home_finance_startup.part.dart').readAsStringSync();
  final real=part.substring(part.indexOf(' Future<void> load()async {'),part.lastIndexOf('\n}')+1);
  expect(pos,greaterThan(0));
  expect(end,greaterThan(pos));
  expect(restored.substring(pos,end),real);
 });
}

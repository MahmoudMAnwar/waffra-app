import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M791 verified Home startup and retry remain registered and fail closed',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_finance_recovery.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_finance_recovery.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeFinanceRecovery on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _loadFinanceSafely()async{')));
  expect(part,contains(' Future<void> _loadFinanceSafely()async{'));
  expect(part,contains(' Widget _financialRecoveryScreen()=>'));
  expect(part,contains('_m627HomeLoadCompletion'));
  expect(part,contains('_m630HomeStartupEpoch'));
  expect(part,contains('await load();'));
  expect(part,contains('_m684InvalidatePeriodRead();'));
  expect(part,contains('_financeLoadFailure'));
  expect(part,contains('Retry safely'));
  expect(part,contains('_m663AwaitVisible('));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('_financeAuthority.commitConfirmedSms(')));
  expect(main,contains(' bool _m621NoticeOpening=false;'));
  expect(main,contains(' @override void dispose(){'));
 });
 test('M791 original secure startup and recovery source is exactly preserved',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' Future<void> _loadFinanceSafely()async{');
  final end=full.indexOf(' bool _m621NoticeOpening=false;',start);
  final part=File('lib/waffra_home_finance_recovery.part.dart').readAsStringSync();
  final body=part.substring(part.indexOf(' Future<void> _loadFinanceSafely()async{'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),body);
 });
}

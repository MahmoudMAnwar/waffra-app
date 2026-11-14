import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M840 real verified Home Widget synchronization is registered and owner checked',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_widget_sync.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_widget_sync.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeWidgetSync on _HomeScreenState'));
  expect(main,isNot(contains(' Future<void> _syncWidgetTransactions()async{')));
  expect(part,contains(' Future<void> _syncWidgetTransactions()async{'));
  expect(part,contains('await _ensureFinanceBound();'));
  expect(part,contains('_financeAuthority.load('));
  expect(part,contains('WaffraFinanceRoute.'));
  expect(part,contains('A failed integrity check never replaces user money with zeroes.'));
  expect(main,contains(' Future<void>? _m474PullRefreshInFlight;'));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
  expect(part,isNot(contains('commitConfirmedSms(')));
 });
 test('M840 unchanged secured widget synchronization is reconstructed exactly',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' Future<void> _syncWidgetTransactions()async{');
  final end=full.indexOf(' Future<void>? _m474PullRefreshInFlight;',start);
  final part=File('lib/waffra_home_widget_sync.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _syncWidgetTransactions()async{'),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M782 original verified finance pull-to-refresh preserves State and confirmed reader',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_verified_refresh.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_verified_refresh.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeVerifiedRefresh on _HomeScreenState'));
  expect(part,contains(' Future<void> _refreshAndSettle('));
  expect(part,contains(' Future<void> _refreshFromVerifiedFinance()async {'));
  expect(main,isNot(contains(' Future<void> _refreshAndSettle(')));
  expect(main,contains(' Future<void>? _m474PullRefreshInFlight;'));
  expect(part,contains('_m474PullRefreshInFlight'));
  expect(part,contains('_financeAuthority'));
  expect(part,contains('WaffraVerifiedPullRefreshSource.fromAuthority(current)'));
  expect(part,isNot(contains('super.dispose()')));
 });
 test('M782 current Home financial refresh source equals real registered Dart-part implementation',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' Future<void> _refreshAndSettle(');
  final end=full.indexOf(' Future<void> load()async {',start);
  final part=File('lib/waffra_home_verified_refresh.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Future<void> _refreshAndSettle('),
   part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}

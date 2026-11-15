import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraHomeLedgerReadCache;

void main(){
 test('M944 expanded Home window exposes at most 50 more cards per action',(){
  final cache=WaffraHomeLedgerReadCache();
  expect(cache.expandedLimit,50);
  expect(cache.revealNext(10),isFalse);
  expect(cache.expandedLimit,50);
  expect(cache.revealNext(125),isTrue);
  expect(cache.expandedLimit,100);
  expect(cache.revealNext(125),isTrue);
  expect(cache.expandedLimit,125);
  expect(cache.revealNext(125),isFalse);
  cache.resetExpanded();
  expect(cache.expandedLimit,50);
  expect(cache.revealNext(10000),isTrue);
  expect(cache.expandedLimit,100);
  cache.invalidate();
  expect(cache.expandedLimit,50);
  expect(()=>cache.revealNext(-1),throwsRangeError);
 });
 test('M944 Home renders bounded windows; explicit PDF still exports all',(){
  final q=File('lib/waffra_home_ledger_query.part.dart').readAsStringSync();
  final dashboard=File('lib/waffra_home_dashboard_analytics.part.dart')
   .readAsStringSync();
  expect(q,contains('static const int expandedPageSize=50;'));
  // M961 keeps the 50-card window and now invalidates month/account views.
  // Assert each real cache field is cleared; never lock the test to a
  // superseded one-line source formatting of invalidate().
  final invalidateStart=q.indexOf('void invalidate(){');
  final invalidateEnd=q.indexOf('}\n}',invalidateStart);
  expect(invalidateStart,greaterThanOrEqualTo(0));
  expect(invalidateEnd,greaterThan(invalidateStart));
  final invalidation=q.substring(invalidateStart,invalidateEnd);
  for(final field in const [
    '_snapshot=null;',
    '_scopedMonthSource=null;',
    '_scopedMonthIds=null;',
    '_scopedMonthResult=null;',
    'resetExpanded();',
  ]) {
    expect(invalidation,contains(field));
  }
  expect(dashboard,contains(
   'limit:min(requestedWindow,_m940LedgerReads.expandedLimit)'));
  expect(dashboard,contains(
   'final maxShown=min(requestedUnified,_m940LedgerReads.expandedLimit)'));
  expect(dashboard,contains('advanceHistoryWindow(toolbarCount)'));
  expect(dashboard,contains('_m945UnifiedHistoryCount=history.length;'));
  expect(dashboard,contains('exportEntriesPdf(fullFilteredTransactions()'));
  expect(dashboard,contains(
   'waffraDashboardTransactionDisplayCount('));
  expect(dashboard,contains("Key('waffra-dashboard-transactions-expand')"));
  expect(dashboard,isNot(contains("Key('waffra-dashboard-unified-activity-expand')")));
 });
}

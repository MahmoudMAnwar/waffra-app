import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verify the extracted production methods, not test-created replacements.
void main(){
 test('M733 real dashboard and analytics remain registered and reconstructable',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_dashboard_analytics.part.dart').readAsStringSync();
  final actual=readWaffraMainSourceForContracts();
  expect(main,contains("part 'waffra_home_dashboard_analytics.part.dart';"));
  expect(main,contains(' // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.'));
  expect(main,isNot(contains(' Widget dashboard(){')));
  expect(part,contains('extension _WaffraHomeDashboardAnalyticsModule on _HomeScreenState {'));
  for(final method in <String>[
   ' Widget dashboard(){',
   ' List<MoneyEntry> get analysisEntries=>',
   ' Widget nextMonthForecast(){',
   ' Future<void> showAiAnalysis()async {',
   ' Widget analytics(){',
  ]){
   expect(part,contains(method));
   expect(actual,contains(method));
  }
  expect(actual.indexOf(' Widget dashboard(){'),
   lessThan(actual.indexOf(' Future<BudgetCategory?> categoryDialog(')));
  expect(actual,contains('_m467SelectedAccount'));
  expect(actual,contains('WaffraDisplayCurrency'));
 });
}

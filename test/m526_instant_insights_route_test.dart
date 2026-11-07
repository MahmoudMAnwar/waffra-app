import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  final start = source.indexOf('Future<void> showAiAnalysis()async');
  final end = source.indexOf('Widget _analysisStat(', start);
  final method = start < 0 || end < start ? '' : source.substring(start, end);

  test('M526 shows calculated insights without an artificial timed wait', () {
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final calculated = method.indexOf('final weeklySpend=smartCharts.weeklySpend;');
    final results = method.indexOf('await showGeneralDialog<void>(');
    expect(calculated, greaterThanOrEqualTo(0));
    expect(results, greaterThan(calculated));
    final between = method.substring(calculated, results);
    // Empty-data prompts elsewhere in this function remain allowed.
    expect(between, isNot(contains('await showWaffraDialog<void>(')));
    expect(between, isNot(contains('waffraMotion(1500)')));
    expect(between, isNot(contains('Future<void>.delayed(')));
    expect(between, contains('if(!mounted)return;'));
  });

  test('M526 retains report, export and empty-history route', () {
    expect(method, contains('if(recent.isEmpty)'));
    expect(method, contains('await showWaffraDialog<bool>('));
    expect(method, contains('await showGeneralDialog<void>('));
    expect(method, contains('barrierDismissible:true'));
    expect(method, contains('smartCharts.topCategories'));
    expect(method, contains('exportEntriesPdf(recent,'));
    expect(method, contains('Waffra analytics - Last 90 days'));
  });
}

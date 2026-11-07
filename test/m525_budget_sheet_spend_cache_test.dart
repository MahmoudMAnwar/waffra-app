import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/waffra_budget_directory.part.dart').readAsStringSync();
  final panelStart = source.indexOf('Widget _budgetDirectoryPanel(');
  final panel = panelStart < 0 ? '' : source.substring(panelStart);

  test('M525: calculate a saved budget only once per sheet rebuild', () {
    expect(panelStart, greaterThanOrEqualTo(0));
    // Changing the ordering comparator must not re-traverse a large ledger.
    expect(RegExp(r'waffraNamedBudgetSpent\(').allMatches(panel).length, 1);
    expect(panel, contains('final spentByBudgetId=<String,double>{};'));
    expect(panel, contains('spentByBudgetId.putIfAbsent('));
    expect(panel, contains(
        'b.id,()=>waffraNamedBudgetSpent(entries,categories,b,now)'));
    expect(panel, contains('spentFor(b).compareTo(spentFor(a))'));
    expect(panel, contains('final spent=spentFor(b);'));
  });

  test('M525: saved budget search, status and finance are unchanged', () {
    expect(panel, contains("budgetStatusFilter=='active'"));
    expect(panel, contains("budgetStatusFilter=='inactive'"));
    expect(panel, contains('waffraSearchAny(['));
    expect(panel, contains("budgetSort=='name'"));
    expect(panel, contains("budgetSort=='limit'"));
    expect(panel, contains("budgetSort=='spent'"));
    expect(panel, contains('final now=DateTime.now();'));
    expect(panel, isNot(contains('_financeAuthority.saveCaptured(')));
    expect(panel, isNot(contains('persist(')));
  });

  test('M525: local spend cache reuses values and is not global state', () {
    // Assert source-level placement: cache is inside the presentation rebuild,
    // after filtering and before sorting, not stored on the encrypted ledger.
    final filterIndex = panel.indexOf('final filtered=saved.where(');
    final cacheIndex = panel.indexOf('final spentByBudgetId=');
    final sortIndex = panel.indexOf("if(budgetSort=='spent')");
    final rowIndex = panel.indexOf('final spent=spentFor(b);');
    expect(filterIndex, greaterThanOrEqualTo(0));
    expect(cacheIndex, greaterThan(filterIndex));
    expect(sortIndex, greaterThan(cacheIndex));
    expect(rowIndex, greaterThan(sortIndex));
    expect(source.substring(0, panelStart),
        isNot(contains('spentByBudgetId')));
  });
}

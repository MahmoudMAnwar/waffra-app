import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

/// Negative-source test matrix coverage != productive SQLCipher certification.
/// This test only ensures the M236 CI YAML really dispatches every remaining
/// canonical route exactly once; it never activates the finance source.
void main() {
  test('M241 actual workflow dispatch covers exactly twenty remaining routes',
      () {
    final lines = File('.github/workflows/m236-parallel-20-route-qa.yml')
        .readAsLinesSync();
    final routeLine = lines.indexWhere((line) =>
        line.startsWith('        ') && line.trim() == 'route:');
    expect(routeLine, greaterThanOrEqualTo(0),
        reason: 'M236 workflow has no route matrix.');

    final dispatched = <String>[];
    for (final line in lines.skip(routeLine + 1)) {
      if (!line.startsWith('          - ')) break;
      dispatched.add(line.substring(12).trim());
    }

    const m235 = <WaffraFinanceRoute>{
      WaffraFinanceRoute.categoryCatalogInstall,
      WaffraFinanceRoute.receiptCopyAndAttach,
      WaffraFinanceRoute.receiptView,
      WaffraFinanceRoute.backupExport,
    };
    final expected = WaffraFinanceRoute.values
        .toSet()
        .difference(m235)
        .map((route) => route.name)
        .toSet();

    expect(dispatched.length, 20);
    expect(dispatched.toSet().length, dispatched.length,
        reason: 'Duplicate matrix jobs cannot stand in for missing routes.');
    expect(dispatched.toSet(), expected,
        reason: 'Actual Actions jobs must match the canonical route enum.');
    expect(
        File('test/storage/m236_remaining_20_route_matrix_test.dart')
            .readAsStringSync(),
        contains(r'M236 ${route.name} source boundary and caller wiring QA only'),
        reason: 'Matrix jobs must use independently named route tests.');
  });
}

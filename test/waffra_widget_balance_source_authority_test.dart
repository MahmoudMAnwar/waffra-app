import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_authoritative_widget_balance.dart';

void main() {
  test('M213 real ledger projection sums each transaction in halalas', () {
    final net = WaffraAuthoritativeWidgetBalance.netHalalas('''
[
 {"id":"incoming","income":true,"amount":225.00,
  "notes":"Synthetic private multilingual SMS\nريال SAR"},
 {"id":"outgoing","income":false,"amount":84.72},
 {"id":"small","income":false,"amount":0.01},
 {"id":"refund","income":true,"amount":16.50}
]
''');
    expect(net, 15677);
    expect(WaffraAuthoritativeWidgetBalance.netHalalas('[]'), 0);
  });

  test('M213 invalid, duplicated or unverified ledger fails closed', () {
    for (final candidate in <String>[
      '{}', 'null', '[1]', '[{"id":"noAmount","income":true}]',
      '[{"id":"one","income":"yes","amount":1}]',
      '[{"id":"one","income":false,"amount":-5}]',
      '[{"id":"x","income":false,"amount":1000000000001}]',
      '[{"id":"same","income":false,"amount":2},'
          '{"id":"same","income":true,"amount":3}]',
      '[{"id":"","income":false,"amount":1}]',
      'not json',
    ]) {
      expect(() => WaffraAuthoritativeWidgetBalance.netHalalas(candidate),
          throwsA(anything),reason:'Invalid financial ledger must never '
          'show a stale balance');
    }
  });

  test('M213 Home and Widget source-bound refresh cannot use local cache', () {
    final home = File('lib/main.dart').readAsStringSync();
    final widget = File('lib/waffra_widget_capture.part.dart').readAsStringSync();
    final homeStart = home.indexOf('Future<void> _refreshWidget()async{');
    final homeEnd = home.indexOf('Future<void> persist({',homeStart);
    expect(homeStart, greaterThan(0));
    expect(homeEnd, greaterThan(homeStart));
    final homeBody = home.substring(homeStart,homeEnd);
    expect(homeBody,
        contains('route:WaffraFinanceRoute.widgetBalanceRefresh'));
    expect(homeBody,
        contains('WaffraAuthoritativeWidgetBalance.netHalalas(raw)'));
    expect(homeBody, contains("balance:'***',negative:false,hidden:true"));
    expect(homeBody, isNot(contains('entries.where(')));

    final widgetStart = widget.indexOf('// Refresh the circular balance');
    final widgetEnd = widget.indexOf('final ignored=outcome.skipped;',
        widgetStart);
    expect(widgetStart, greaterThan(0));
    expect(widgetEnd, greaterThan(widgetStart));
    final widgetBody = widget.substring(widgetStart,widgetEnd);
    expect(widgetBody,
        contains('route:WaffraFinanceRoute.widgetBalanceRefresh'));
    expect(widgetBody,contains(
        'WaffraAuthoritativeWidgetBalance.netHalalas(verified.ledgerRaw!)'));
    expect(widgetBody,contains('verified.finance.requireIntegrity()'));
    expect(widgetBody,contains("balance:'***',negative:false,hidden:true"));
    expect(widgetBody,isNot(contains('outcome.merged.where(')));
    expect(home,contains('refreshVerifiedWidgetBalance:_refreshWidget'));
    expect(home,isNot(contains("balance:conceal?'***':formatWaffraMoney(balance)")));
  });
}

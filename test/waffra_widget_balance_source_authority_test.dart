import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_authoritative_widget_balance.dart';

void main() {
  test('M213 real ledger projection sums each transaction in halalas', () {
    final net = WaffraAuthoritativeWidgetBalance.netHalalas(r'''
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

  test('M636 Home verified balance remains the only widget finance source',(){
    final home=File('lib/main.dart').readAsStringSync();
    final native=File('native/WaffraWidget.kt').readAsStringSync();
    final bridge=File('lib/waffra_home_widget.dart').readAsStringSync();
    final homeStart=home.indexOf('Future<void> _refreshWidget()async{');
    final homeEnd=home.indexOf('Future<void> persist({',homeStart);
    expect(homeStart,greaterThan(0));
    expect(homeEnd,greaterThan(homeStart));
    final body=home.substring(homeStart,homeEnd);
    expect(body,contains('route:WaffraFinanceRoute.widgetBalanceRefresh'));
    expect(body,contains('WaffraAuthoritativeWidgetBalance.netHalalas(raw)'));
    expect(body,contains("balance:'***',negative:false,hidden:true"));
    expect(body,isNot(contains('entries.where(')));
    expect(home,contains('refreshVerifiedWidgetBalance:_refreshWidget'));
    expect(home,contains('if(!mounted||!ready||waffraWidgetAction.value!=\'add\')return;'));
    expect(native,contains('Intent(context, MainActivity::class.java)'));
    expect(native,isNot(contains('commitConfirmedSms(')));
    expect(bridge,contains("invokeMethod<void>('updateSummary'"));
    expect(File('lib/waffra_widget_capture.part.dart').existsSync(),isFalse);
    expect(home,isNot(contains("balance:conceal?'***':formatWaffraMoney(balance)")));
  });
}

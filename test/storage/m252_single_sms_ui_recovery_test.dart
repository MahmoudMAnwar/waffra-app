import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M252 single-SMS save never hides a failed commit or stale balance', () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf('if(pendingHash!=null&&initial==null){');
    final end = home.indexOf('  }else{', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final flow = home.substring(start, end);

    expect(flow, contains('await _financialWriteQueue.drain();'));
    expect(flow, contains('waffraCanConfirmSmsWithFinanceSource('));
    expect(flow, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
    expect(flow, contains('userConfirmed:true,'));
    expect(flow, contains('hashes:[pendingHash!]'));
    final commit = flow.indexOf(
      'final applied=await _financeAuthority.commitConfirmedSms(',
    );
    final firstDrain = flow.indexOf('await _financialWriteQueue.drain();');
    final ready = flow.indexOf('waffraCanConfirmSmsWithFinanceSource(');
    final paint = flow.indexOf('entries..clear()..addAll(verified);');
    expect(firstDrain, lessThan(ready));
    expect(ready, lessThan(commit));
    expect(commit, lessThan(paint));

    final failure = flow.substring(flow.indexOf('}catch(e){'));
    final reload = failure.indexOf('await _loadFinanceSafely();');
    expect(reload, greaterThan(failure.indexOf('await _financialWriteQueue.drain();')));
    expect(failure, isNot(contains('entries..clear()..addAll(')));
    expect(failure, contains('حالة حفظ العملية البنكية غير مؤكدة'));
    expect(failure, contains('return;'));
  });

  test('M252 manual save failure waits for Home writes before source recovery', () {
    final home = File('lib/main.dart').readAsStringSync();
    final marker = home.indexOf(
      "debugPrint('Transaction source commit could not be verified: ",
    );
    expect(marker, greaterThanOrEqualTo(0));
    final failure = home.substring(marker, marker + 1000);
    final drain = failure.indexOf('await _financialWriteQueue.drain();');
    final reload = failure.indexOf('await _loadFinanceSafely();');
    expect(drain, greaterThan(0));
    expect(reload, greaterThan(drain));
    expect(failure, contains('    return;'));
  });
}

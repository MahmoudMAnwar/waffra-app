import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M250 uncertain bulk SMS save re-reads real source before retry', () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf(
      'Future<void> saveParsedMessages(BuildContext ctx,StateSetter update)async {',
    );
    final end = home.indexOf('void disposeLater(){', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final flow = home.substring(start, end);

    expect(flow, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
    expect(flow, contains('userConfirmed:true,'));
    expect(flow, contains('final applied=await _financeAuthority.commitConfirmedSms('));
    expect(flow, contains('if(recovery.saved!=applied.saved){'));

    // Commit can have succeeded even when the following read/reconcile threw.
    // On every uncertain exception the only safe UI is a freshly selected
    // authoritative ledger, not a blind retry against stale in-memory entries.
    final failure = flow.lastIndexOf('}catch(e){');
    final catchFlow = flow.substring(failure);
    expect(failure, greaterThan(0));
    final sourceReload = catchFlow.indexOf('await _loadFinanceSafely();');
    final busyReset = catchFlow.indexOf('busy=false;');
    final message = catchFlow.indexOf('Save status could not be verified.');
    expect(sourceReload, greaterThan(0));
    expect(busyReset, greaterThan(sourceReload));
    expect(message, greaterThan(busyReset));
    expect(catchFlow, isNot(contains('entries..clear()..addAll(')));
    expect(catchFlow, contains('راجع معاملاتك المحدّثة قبل إعادة المحاولة.'));
  });
}

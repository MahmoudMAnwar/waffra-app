import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_sms_source_write_readiness.dart';

void main() {
  test('M251 SMS write readiness refuses all incomplete source witnesses', () {
    for (final ready in <bool>[false, true]) {
      for (final hasRead in <bool>[false, true]) {
        for (final recovering in <bool>[false, true]) {
          final allowed = waffraCanConfirmSmsWithFinanceSource(
            dashboardReady: ready,
            hasVerifiedRead: hasRead,
            recoveryActive: recovering,
          );
          expect(
            allowed, ready && hasRead && !recovering,
            reason: 'Source checks must fail closed in recovery.',
          );
        }
      }
    }
  });

  test('M251 bank SMS entry, confirmation and SQL write all recheck readiness', () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf(
      'Future<void> saveParsedMessages(BuildContext ctx,StateSetter update)async {',
    );
    final end = home.indexOf('void disposeLater(){', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final flow = home.substring(start, end);
    expect('waffraCanConfirmSmsWithFinanceSource('.allMatches(flow).length, 3);
    final openingCheck = flow.indexOf('waffraCanConfirmSmsWithFinanceSource(');
    final confirmDialog = flow.indexOf('final accepted=await showWaffraDialog<bool>');
    final checkAfterConfirm = flow.indexOf(
      'waffraCanConfirmSmsWithFinanceSource(', openingCheck + 1,
    );
    final drain = flow.indexOf('await _financialWriteQueue.drain();');
    final checkBeforeCommit = flow.indexOf(
      'waffraCanConfirmSmsWithFinanceSource(', checkAfterConfirm + 1,
    );
    final commit = flow.indexOf(
      'final applied=await _financeAuthority.commitConfirmedSms(',
    );
    expect(openingCheck, lessThan(confirmDialog));
    expect(checkAfterConfirm, greaterThan(confirmDialog));
    expect(checkAfterConfirm, lessThan(drain));
    expect(checkBeforeCommit, greaterThan(drain));
    expect(checkBeforeCommit, lessThan(commit));
    final failure = flow.substring(flow.lastIndexOf('}catch(e){'));
    expect(failure, contains('await _financialWriteQueue.drain();'));
    expect(failure, contains('await _loadFinanceSafely();'));
    expect(
      failure.indexOf('await _financialWriteQueue.drain();'),
      lessThan(failure.indexOf('await _loadFinanceSafely();')),
    );
    expect(flow, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
    expect(flow, contains('userConfirmed:true,'));
  });
}

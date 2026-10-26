import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M249 rejected manual or edited finance write cannot leave a ghost balance', () {
    final home = File('lib/main.dart').readAsStringSync();
    final start = home.indexOf('if(pendingHash!=null&&initial==null){');
    final end = home.indexOf('if(mounted)await budgetAlert(result,previousSpent);', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final saveFlow = home.substring(start, end);

    // The save still carries the correct finance route and explicit consent.
    expect(saveFlow, contains('await persist(route:initial==null'));
    expect(saveFlow, contains('WaffraFinanceRoute.manualTransactionSave'));
    expect(saveFlow, contains('WaffraFinanceRoute.transactionEdit'));
    expect(saveFlow, contains('userConfirmed:initial==null);'));

    // Home can paint optimistically, but a rejected or ambiguous commit must
    // reread the authoritative ledger before the user can act on that data.
    final tryAt = saveFlow.indexOf('try{\n    await persist(');
    final catchAt = saveFlow.indexOf('}catch(e){', tryAt);
    final reloadAt = saveFlow.indexOf('await _loadFinanceSafely();', catchAt);
    final returnAt = saveFlow.indexOf('    return;', reloadAt);
    expect(tryAt, greaterThanOrEqualTo(0));
    expect(catchAt, greaterThan(tryAt));
    expect(reloadAt, greaterThan(catchAt));
    expect(returnAt, greaterThan(reloadAt));
    expect(saveFlow, contains('Transaction save was not verified.'));
    expect(saveFlow, contains('تعذر التحقق من حفظ العملية.'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M266: verify live Home entry points bind the finance authority before
/// source-dependent operations. This is source-level regression evidence,
/// not a physical-device or production SQLCipher activation certificate.
void main() {
  final app = File('lib/main.dart').readAsStringSync();

  String between(String start, String end) {
    final from = app.indexOf(start);
    expect(from, greaterThanOrEqualTo(0), reason: 'Missing $start');
    final until = app.indexOf(end, from + start.length);
    expect(until, greaterThan(from), reason: 'Missing ending $end');
    return app.substring(from, until);
  }

  void ensureBefore(String source, String operation) {
    final bind = source.indexOf('await _ensureFinanceBound();');
    final use = source.indexOf(operation);
    expect(bind, greaterThanOrEqualTo(0), reason: 'Missing finance bind');
    expect(use, greaterThan(bind), reason: 'Finance operation preceded bind');
  }

  test('Home cold Widget sync must bind before dashboard source read', () {
    ensureBefore(
      between('Future<void> _syncWidgetTransactions()async{',
          'Future<void> _refreshFromVerifiedFinance()async'),
      '_financeAuthority.load(route:WaffraFinanceRoute.dashboardRead)',
    );
  });

  test('queued Home writes bind source after capturing immutable snapshot', () {
    final body = between('Future<void> persist({',
        'Future<void> _persistSmsHashes(');
    expect(body, contains('final snapshot=<String,Object>{'));
    expect(body, contains('return _financialWriteQueue.submit(snapshot,'));
    ensureBefore(body, '_financeAuthority.saveCaptured(');
  });

  test('SMS fingerprints and recurring preferences use bound authority', () {
    ensureBefore(
      between('Future<void> _persistSmsHashes(', 'Future<void> syncRecurringReminders()'),
      '_financeAuthority.mergeSmsHashes(',
    );
    ensureBefore(
      between('Future<void> toggleRecurringReminders(bool enabled)async',
          'Future<void> applyRecurring()async'),
      '_financeAuthority.setRecurringReminderPreference(',
    );
  });

  test('goals and backup request verified finance binding before reads', () {
    ensureBefore(
      between('Future<void> goalDialog()async', 'Future<void>'),
      '_financeAuthority.loadCustomGoalSuggestions(',
    );
    ensureBefore(
      between('Future<void> backupDialog()async', 'Future<void>'),
      '_financeAuthority.load(',
    );
  });

  test('Home source selection still starts through guarded production binding',
      () {
    expect(app, contains('WaffraProductionFinanceAuthorityBinding.bind('));
    expect(app, contains('startupRoute:WaffraFinanceRoute.appStartup'));
    expect(app, contains('final pending=_financeBindingFuture??=_bindFinanceSource();'));
  });
}

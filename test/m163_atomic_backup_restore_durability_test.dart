import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M163 backup restore commits all finance before publishing UI state', () {
    final source = File('lib/main.dart').readAsStringSync();
    final dialogStart = source.indexOf('Future<void> backupDialog()');
    final dialogEnd = source.indexOf(
      '// System credentials are never saved', dialogStart);
    expect(dialogStart, greaterThanOrEqualTo(0));
    expect(dialogEnd, greaterThan(dialogStart));
    final dialog = source.substring(dialogStart, dialogEnd);
    final authorized = dialog.indexOf(
      "_authorizeSensitiveAction('restoring data')");
    expect(authorized, greaterThanOrEqualTo(0));
    final restore = dialog.substring(authorized);

    final confirmed = restore.indexOf('final restoreSnapshot=<String,Object>{');
    final queued = restore.indexOf(
      'await _financialWriteQueue.submit(restoreSnapshot,(captured)async{');
    final sourceRead = restore.indexOf(
      'await _financeAuthority.load(', queued);
    final durableWrite = restore.indexOf(
      'await _financeAuthority.saveCaptured(', sourceRead);
    final firstPublishedUi = restore.indexOf('setState((){', durableWrite);
    final reminder = restore.indexOf('await syncRecurringReminders();');
    expect(confirmed, greaterThanOrEqualTo(0));
    expect(queued, greaterThan(confirmed));
    expect(sourceRead, greaterThan(queued));
    expect(durableWrite, greaterThan(sourceRead));
    expect(firstPublishedUi, greaterThan(durableWrite));
    expect(reminder, greaterThan(firstPublishedUi));

    expect(restore, contains('route:WaffraFinanceRoute.backupRestore'));
    expect(restore, contains("'waffra_sms_hashes_v1':restoredHashes.toList()..sort()"));
    expect(restore, contains('smsHashes..clear()..addAll(restoredHashes)'));
    expect(restore, contains("RegExp(r'^[0-9a-f]{64}\$')"));
    expect(restore, contains('hashesPayload.length>100000'));
    expect(restore, isNot(contains('await persist();')));
    expect(restore, contains('unawaited(_refreshWidget());'));
  });

  test('M163 encrypted restore cannot bypass verified source authority', () {
    final authority = File(
      'lib/storage/waffra_verified_finance_authority.dart',
    ).readAsStringSync();
    expect(authority, contains('final backend = await _requireRoute(route);'));
    expect(authority, contains('if (backend != baseline.source)'));
    expect(authority, contains('await legacy.saveLegacy('));
    expect(authority, contains('!projectedEditorRoutes.contains(route)'));
    expect(authority, isNot(contains('WaffraFinanceRoute.backupRestore,')));
    final legacy = File(
      'lib/storage/waffra_home_finance_persistence.dart',
    ).readAsStringSync();
    expect(legacy, contains('await batch.prepare(prefs: preferences, nextValues: captured);'));
    expect(legacy, contains('await batch.recover(preferences);'));
  });
}

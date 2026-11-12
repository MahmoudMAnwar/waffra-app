import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M638 native reconciliation removes only missing unconfirmed review IDs',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final start=native.indexOf('fun reconcilePendingWithInbox(context: Context): Int');
  final end=native.indexOf('fun restartCompletedHistory(context: Context)',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final reconcile=native.substring(start,end);
  expect(reconcile,contains('permissionGranted(context)'));
  expect(reconcile,contains('signedInOwnerHash(context)'));
  expect(reconcile,contains('Uri.parse("content://sms/inbox")'));
  expect(reconcile,contains('if (++scanned > 50000)'));
  expect(reconcile,contains('throw IllegalStateException("Android SMS inbox scan incomplete")'));
  expect(reconcile,contains('initialIds.contains(fingerprint)'));
  expect(reconcile,contains('!present.contains(fingerprint)'));
  expect(reconcile,contains('receivedAt < recentFloor'));
  expect(reconcile,contains('if (removed > 0)'));
  expect(reconcile,contains('save(context, retained)'));
  expect(reconcile,isNot(contains('acknowledgeCommitted(')));
  expect(reconcile,isNot(contains('excludeMessages(')));
  expect(reconcile,isNot(contains('deleteAndroidSms')));
  expect(reconcile,isNot(contains('historyCursorAt).remove(')));
 });

 test('M638 explicit Rescan alone calls background native inbox sync',(){
  final main=File('lib/main.dart').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final begin=main.indexOf(' Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{');
  final end=main.indexOf(' Future<void>? _autoSmsRefreshInFlight;',begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final explicit=main.substring(begin,end);
  expect(explicit,contains('WaffraAutoSms.reconcilePendingWithAndroidInboxChecked()'));
  expect(explicit,contains('await _refreshAutoSmsInbox(importMonth:true)'));
  final passive=main.substring(main.indexOf(' Future<void> _runAutoSmsRefresh('),
   main.indexOf(' Future<void> _scanPreviousBankSmsFromSettings()async{'));
  expect(passive,isNot(contains('reconcilePendingWithAndroidInboxChecked()')));
  expect(bridge,contains("'reconcilePendingAutoBankSmsWithAndroidInbox'"));
  final route=activity.substring(activity.indexOf(
   '"reconcilePendingAutoBankSmsWithAndroidInbox" -> {'));
  expect(route,contains('smsHistoryExecutor.execute {'));
  expect(route,contains('WaffraAutoSmsStore.reconcilePendingWithInbox(app)'));
  expect(route,contains('result.error("SMS_INBOX_SYNC_UNAVAILABLE"'));
 });

 test('M638 saved money, durable dedup and 30-day exclusions are never cleaned by sync',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final block=native.substring(
   native.indexOf('fun reconcilePendingWithInbox(context: Context): Int'),
   native.indexOf('fun restartCompletedHistory(context: Context)'));
  for(final forbidden in <String>[
   'committedBucketPrefix','excludedMessageBucketPrefix',
   'excludedMessageInfoBucketPrefix','completedTransferBucketPrefix',
   'WaffraEncryptedFinanceSession','historyCursorId','historyCursorAt',
  ]){
   expect(block,isNot(contains(forbidden)),reason:forbidden);
  }
  expect(native,contains('private const val excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
 });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M1018 / Issue #735: source-level WorkManager scheduling contract.
/// Android JobScheduler behavior still requires an on-device test.
void main(){
 test('M1018 accepts encrypted messages before scheduling exactly once per broadcast',(){
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(receiver,contains('SMS_RECEIVED_ACTION'));
  expect(receiver,contains('WaffraAutoSmsStore.enabled(context)'));
  expect(receiver,contains('for ((sender, parts) in bySender) {'));
  expect(receiver,contains('var shouldEnqueue = false'));
  expect(receiver,contains('shouldEnqueue = true'));
  expect(receiver,contains('if (shouldEnqueue) WaffraAutoSmsWorker.enqueue(context)'));
  expect('WaffraAutoSmsWorker.enqueue(context)'.allMatches(receiver),hasLength(1),
   reason:'one successor per received broadcast, not one expensive job per sender');
  expect(receiver.indexOf('WaffraAutoSmsStore.offer(context, sender, parts.toString()'),
   lessThan(receiver.indexOf('if (shouldEnqueue) WaffraAutoSmsWorker.enqueue(context)')));
  expect(receiver,isNot(contains('commitConfirmedSms(')));
  expect(receiver,isNot(contains('acknowledgeCommitted(')));
 });

 test('M1018 a new SMS appends a worker while older worker may still be running',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  final scheduler=worker.split('fun enqueue(context: Context) {')[1];
  expect(scheduler,contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
  expect(scheduler,contains(
   '"waffra_auto_sms_finance", ExistingWorkPolicy.APPEND_OR_REPLACE, work'));
  expect(scheduler,isNot(contains('ExistingWorkPolicy.KEEP')));
  expect(scheduler,isNot(contains('ExistingWorkPolicy.REPLACE')));
  expect(scheduler,isNot(contains('ExistingWorkPolicy.APPEND, work')));
  // An active Flutter/SQLCipher worker must not be cancelled just to wake up
  // a new SMS; failed/cancelled dependencies must not poison later arrivals.
  expect(worker,contains('OneTimeWorkRequestBuilder<WaffraAutoSmsWorker>()'));
  expect(worker,contains('setBackoffCriteria(BackoffPolicy.EXPONENTIAL'));
  expect(worker,contains('Result.retry()'));
 });

 test('M1018 preserves foreground guard and finance ownership boundaries',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(worker,contains('if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context)) return'));
  expect(worker,contains('if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context))'));
  expect(worker,contains('val completed = try { done.await(55, TimeUnit.SECONDS) }'));
  expect(worker,contains('main.post { engine?.destroy() }'));
  expect(worker,contains('waffraAutoSmsBackgroundEntrypoint'));
  expect(worker,isNot(contains('FirebaseFirestore')));
  expect(worker,isNot(contains('commitConfirmedSms(')));
  expect(receiver,isNot(contains('FirebaseFirestore')));
 });

 test('M1018 review notifications and committed-only ACK remain separated',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('"notifyAutoSmsNeedsReview" -> {'));
  expect(worker,contains('WaffraAutoSmsNotifications.notifyReview('));
  expect(worker,contains('"ackCommittedAutoBankSms" -> {'));
  expect(worker,contains('WaffraAutoSmsStore.acknowledgeCommitted(context, ids)'));
  expect(worker,contains('"excludeAutoBankSms" -> {'));
  expect(worker,contains('WaffraAutoSmsStore.excludeMessages(context, ids)'));
 });
}

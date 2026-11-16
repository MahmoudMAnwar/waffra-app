import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1028 failed encrypted SMS processing stays retryable without hard fail',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('Result.retry()'));
  expect(worker,contains('else if (WaffraAutoSmsStore.enabled(context)) Result.retry()'));
  expect(worker,contains('else Result.success()'));
  expect(worker,isNot(contains('else Result.failure()')));
  expect(worker,isNot(contains('runAttemptCount < 2')));
 });
 test('M1028 backoff and owner gates survive foreground, logout and service failure',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('.setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 20, TimeUnit.SECONDS)'));
  expect(worker,contains('if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context))'));
  expect(worker,contains('done.await(55, TimeUnit.SECONDS)'));
  expect(worker,contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
  expect(worker,isNot(contains('commitConfirmedSms(')));
 });
}

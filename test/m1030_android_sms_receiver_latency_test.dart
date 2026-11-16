import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1030 receiver never performs encrypted queue writes synchronously',(){
  final s=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  final onReceive=s.split('override fun onReceive(context: Context, intent: Intent) {')[1];
  expect(onReceive,contains('val pending = goAsync()'));
  expect(onReceive,contains('smsIntakeExecutor.execute {'));
  expect(onReceive.indexOf('val pending = goAsync()'),
   lessThan(onReceive.indexOf('WaffraAutoSmsStore.offer(context,')));
  expect(onReceive,contains('finally { pending.finish() }'));
  expect(onReceive,contains('catch (_: Exception) { pending.finish() }'));
  expect(s,contains('private val smsIntakeExecutor'));
  expect(s,isNot(contains('commitConfirmedSms(')));
 });
 test('M1030 owner consent, one WorkManager successor and sender-time boundaries',(){
  final s=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(s,contains('if (!WaffraAutoSmsStore.enabled(context)) return@execute'));
  expect(s,contains('val bySenderAndTimestamp ='));
  expect(s,contains('linkedMapOf<Triple<String, Long, String>, StringBuilder>()'));
  expect(s,contains('var shouldEnqueue = false'));
  expect('WaffraAutoSmsWorker.enqueue(context)'.allMatches(s),hasLength(1));
  expect(s,contains('WaffraAutoSmsStore.capacityRecoveryNeeded(context)'));
 });
}

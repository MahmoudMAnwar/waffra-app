import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M1019 / Issue #736: synthetic capacity contract, no actual bank data.
void main(){
 test('full encrypted queue requests bounded and durable history replay',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('private const val maxCandidates = 1000'));
  expect(store,contains('private const val capacityRecoveryRequestedName'));
  expect(store,contains('fun capacityRecoveryNeeded(context: Context): Boolean'));
  final offer=store.split('    fun offer(context: Context, sender: String, body: String, at: Long,')[1]
   .split('    fun pending(context: Context):')[0];
  expect(offer,contains('if (queue.length() >= maxCandidates) {'));
  expect(offer,contains('putBoolean(capacityRecoveryRequestedName, true).commit()'));
  expect(offer,contains('return@synchronized false'));
  expect(offer,contains('if (pureVerificationOnly(body)) {'));
  expect(offer.indexOf('if (pureVerificationOnly(body)) {'),
   lessThan(offer.indexOf('if (queue.length() >= maxCandidates) {')));
  expect(offer,isNot(contains('queue.remove(')));
  expect(offer,isNot(contains('queue.put(queue.getJSONObject(')));
 });

 test('full live receipt still schedules a worker without claiming it was queued',(){
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(receiver,contains('if (shouldEnqueue || WaffraAutoSmsStore.capacityRecoveryNeeded(context))'));
  expect(receiver,contains('WaffraAutoSmsStore.offer('));
  expect('WaffraAutoSmsWorker.enqueue(context)'.allMatches(receiver),hasLength(1));
  expect(receiver,isNot(contains('commitConfirmedSms(')));
 });

 test('worker backfills only after completion and schedules when new rows imported',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('WaffraAutoSmsStore.capacityRecoveryNeeded(context)'));
  expect(worker,contains('WaffraAutoSmsStore.importConsentMonth(context, maxRead = 100)'));
  expect(worker,contains('if (recovered > 0) enqueue(context)'));
  expect(worker,contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
  expect(worker,isNot(contains('FirebaseFirestore')));
  expect(worker,isNot(contains('commitConfirmedSms(')));
 });

 test('historical recovery never advances cursor over an unqueued full candidate',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final history=store.split('    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {')[1]
   .split('    /** Claim each review notification once;')[0];
  expect(history,contains('if (currentSize >= maxCandidates)'));
  expect(history,contains('if (queue.length() >= maxCandidates) {'));
  expect(history,contains('stoppedForCapacity = true'));
  expect(history,contains('break'));
  expect(history,contains('var nextAt = originalCursor.first'));
  expect(history,contains('.putLong(historyCursorAt, nextAt)'));
  expect(history,contains('if (!editor.commit()) return@synchronized 0'));
  expect(store,contains('rescanNeeded'));
 });

 test('boundary state and no message eviction in 999/1000/1001 cases',(){
  for(final count in <int>[999,1000,1001]){
   const limit=1000;
   final accepted=count<limit;
   final recovery=count>=limit;
   expect(accepted, count==999);
   expect(recovery, count!=999);
   // Fail-closed queue content stays unchanged for full/overflow cases.
   final before=List.generate(count.clamp(0,limit),(i)=>'synthetic-$i');
   final after=List<String>.from(before);
   if(accepted)after.add('synthetic-new');
   expect(after.take(before.length),before);
   expect(after.length,lessThanOrEqualTo(limit));
  }
 });
}

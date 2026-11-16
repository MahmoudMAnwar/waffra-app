import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_background_batches.dart';

/// M1017 / #734: synthetic messages only; no user SMS/phone/OTP data.
void main() {
 test('M1017 drains zero, boundary, and 1000 candidates exactly once', () {
  for (final count in <int>[0, 1, 24, 25, 26, 50, 51, 100, 101, 1000]) {
   final messages=List<String>.generate(count,(i)=>'synthetic-$i');
   final batches=waffraSmsBackgroundBatches(messages).toList();
   expect(batches.every((batch)=>batch.isNotEmpty&&batch.length<=25),isTrue,
    reason:'bounded work batches for $count candidates');
   final processed=batches.expand((batch)=>batch).toList();
   expect(processed,messages,reason:'must preserve order and never strand tail $count');
   expect(processed.toSet(),hasLength(count),reason:'no double attempts');
   if(count>25)expect(batches.length,greaterThan(1));
  }
 });

 test('M1017 rejects invalid batch sizes and retains custom bounded sizes', () {
  expect(()=>waffraSmsBackgroundBatches([1],batchSize:0).toList(),
   throwsArgumentError);
  expect(()=>waffraSmsBackgroundBatches([1],batchSize:-1).toList(),
   throwsArgumentError);
  expect(waffraSmsBackgroundBatches(List<int>.generate(52,(i)=>i),
   batchSize:7).expand((batch)=>batch),orderedEquals(
    List<int>.generate(52,(i)=>i)));
 });

 test('M1017 worker processes every batch without a first-25 cap', () {
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final source=worker.substring(worker.indexOf('if(actionable.isEmpty)return summary;'));
  expect(source,contains('for(final batch in waffraSmsBackgroundBatches(actionable))'));
  expect(source,contains('for(final candidate in batch){'));
  expect(source,isNot(contains('for(final candidate in actionable.take(25))')));
  expect(source,contains('await keepForReview(candidate)'));
  expect(source,contains('WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(source,contains('WaffraAutoSms.excludeMessages([id])'),
   reason:'durable excluded IDs must survive rescan');
  expect(source,contains('binding?.close()'));
 });
}

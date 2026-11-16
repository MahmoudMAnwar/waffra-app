import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_background_checkpoint.dart';

Map<String,Object?> sms(int i,{bool attempted=false})=> <String,Object?>{
 'id':'synthetic-$i','backgroundAttempted':attempted,
};

void main(){
 test('M1020 no repeat of reviewed rows; 26, 100, 1000 traverse across bounded passes',(){
  for(final count in <int>[0,1,24,25,26,100,1000]){
   final queue=List.generate(count,(i)=>sms(i));
   final processed=<String>[];
   var passes=0;
   while(true){
    final plan=WaffraSmsBackgroundCheckpoint.select(queue,maxPerPass:25);
    if(plan.candidates.isEmpty)break;
    expect(plan.candidates.length,lessThanOrEqualTo(25));
    for(final row in plan.candidates){
     processed.add(row['id'] as String);
     row['backgroundAttempted']=true;
    }
    passes++;
    expect(passes,lessThanOrEqualTo(40));
   }
   expect(processed,hasLength(count));
   expect(processed.toSet(),hasLength(count));
   expect(passes,(count+24)~/25);
  }
 });

 test('M1020 deadline makes partial pass resumable without skipping the tail',(){
  final queue=List.generate(26,(i)=>sms(i));
  var plan=WaffraSmsBackgroundCheckpoint.select(queue,maxPerPass:25);
  for(final row in plan.candidates.take(6)){
   row['backgroundAttempted']=true;
  }
  plan=WaffraSmsBackgroundCheckpoint.select(queue,maxPerPass:25);
  expect(plan.candidates.first['id'],'synthetic-6');
  expect(plan.candidates.last['id'],'synthetic-25');
  expect(plan.remaining,0);
  expect(WaffraSmsBackgroundCheckpoint.remainingAfter(26,6),20);
  expect(()=>WaffraSmsBackgroundCheckpoint.select(queue,maxPerPass:0),
   throwsArgumentError);
 });

 test('M1020 review checkpoints remain encrypted, independent of notification claim',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final pending=store.split('    fun pending(context: Context): List<Map<String, Any>>')[1]
    .split('    fun pendingById(context: Context, id: String)')[0];
  expect(pending,contains('"backgroundAttempted" to row.optBoolean("backgroundAttempted", false)'));
  expect(pending,contains('fun markBackgroundSmsReviewed(context: Context, id: String): Boolean'));
  expect(pending,contains('row.put("backgroundAttempted", true)'));
  expect(pending,contains('save(context, data)'));
  expect(pending,isNot(contains('acknowledgeCommitted(')));
  expect(pending,isNot(contains('queue.remove(')));
 });

 test('M1020 35-second budget and 25-per-pass limit replace unbounded runtime',(){
  final source=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(source,contains('final stopwatch=Stopwatch()..start();'));
  expect(source,contains('const budget=Duration(seconds:35);'));
  expect(source,contains('WaffraSmsBackgroundCheckpoint.select(pending,maxPerPass:25)'));
  expect(source,contains('if(stopwatch.elapsed>=budget)'));
  expect(source,contains('summary[\'remaining\']='));
  expect(source,contains('await WaffraAutoSms.markBackgroundReviewed(id)'));
  expect(source,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(source,isNot(contains('actionable.take(25)')));
 });

 test('M1020 Dart entrypoint reports whether successor WorkManager job is needed',(){
  final main=File('lib/main.dart').readAsStringSync();
  final entry=main.substring(main.indexOf('void waffraAutoSmsBackgroundEntrypoint()'),
   main.indexOf('Future<void> main()async {'));
  expect(entry,contains('final summary=await WaffraAutoSmsAutoPoster.run();'));
  expect(entry,contains("'hasMore':(summary['remaining']??0)>0"));
  expect(entry,contains("'finished':true"));
  expect(entry,isNot(contains('await WaffraAutoSmsAutoPoster.run();\n   return true;')));
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('reply is Map<*, *>'));
  expect(worker,contains('needsContinuation = reply["hasMore"] == true'));
  expect(worker,contains('if (completed && successful && needsContinuation) enqueue(context)'));
  expect(worker,contains('done.await(55, TimeUnit.SECONDS)'));
  expect(worker,contains('ExistingWorkPolicy.APPEND_OR_REPLACE'));
  expect(worker,isNot(contains('successful = reply == true')));
 });

 test('M1020 no checkpoint before review and ACK outcome on worker channel',(){
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('"markAutoBankSmsBackgroundReviewed" ->'));
  expect(worker,contains('WaffraAutoSmsStore.markBackgroundSmsReviewed(context, id)'));
  final dart=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(dart,contains("return _boolCall('markAutoBankSmsBackgroundReviewed',id);"));
  final poster=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(poster,contains('if(!await WaffraAutoSms.markBackgroundReviewed(id))'));
  expect(poster,contains('if(!await WaffraAutoSms.acknowledgeCommitted([id]))'));
 });
}

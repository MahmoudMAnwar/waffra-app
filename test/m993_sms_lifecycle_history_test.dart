import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_lifecycle_evidence.dart';
import 'package:waffra/waffra_sms_lifecycle_history_store.dart';

void main(){
 test('M993 pending then posted links after encrypted-digest restart',(){
  final index=WaffraSmsRelatedEventIndex();
  final pending=WaffraSmsLifecycleEvidence.inspect(
   'Pending Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  final posted=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  expect(index.inspectAndRemember(pending,nativeId:'source-A'),
   WaffraSmsRelatedEvent.none);
  final stored=index.safeHistory();
  expect(stored.length,1);
  final raw=stored.single.toString();
  expect(raw,isNot(contains('ABC12345')));
  expect(raw,isNot(contains('1234')));
  expect(raw,isNot(contains('source-A')));
  expect((stored.single['key'] as String).length,64);
  expect((stored.single['source'] as String).length,64);
  final restarted=WaffraSmsRelatedEventIndex(prior:stored);
  expect(restarted.inspectAndRemember(posted,nativeId:'source-B'),
   WaffraSmsRelatedEvent.possibleSettlement);
 });

 test('M993 same native message across restart does not flag itself',(){
  final first=WaffraSmsRelatedEventIndex();
  final event=WaffraSmsLifecycleEvidence.inspect(
   'Purchase Card 25 SAR\nAccount: **1234\nRef: ABC12345',
   sender:'AlRajhi');
  expect(first.inspectAndRemember(event,nativeId:'native-1'),
   WaffraSmsRelatedEvent.none);
  final again=WaffraSmsRelatedEventIndex(prior:first.safeHistory());
  expect(again.inspectAndRemember(event,nativeId:'native-1'),
   WaffraSmsRelatedEvent.none);
  expect(again.inspectAndRemember(event,nativeId:'native-2'),
   WaffraSmsRelatedEvent.possibleDuplicate);
 });

 test('M993 malformed, stale and plaintext hint records fail closed',(){
  final now=DateTime.utc(2026,11,15).millisecondsSinceEpoch;
  final key=''.padLeft(64,'a'),source=''.padLeft(64,'b');
  final values=<Map<String,Object?>>[
   {'key':key,'source':source,'stage':'posted','seenAt':now},
   {'key':key,'source':source,'stage':'pending','seenAt':now-1},
   {'key':'raw-bank-reference','source':source,
      'stage':'posted','seenAt':now},
   {'key':key,'source':'raw-native-id',
      'stage':'posted','seenAt':now},
   {'key':''.padLeft(64,'c'),'source':source,
      'stage':'posted','seenAt':now-31*24*3600*1000},
   {'key':''.padLeft(64,'d'),'source':source,
      'stage':'unknown','seenAt':now},
  ];
  final safe=WaffraSmsLifecycleHistoryStore.sanitize(
   values,nowMillis:now);
  expect(safe.length,1);
  expect(safe.single['stage'],'posted');
  expect(safe.single['key'],key);
 });

 test('M993 memory remains capped after 2000 unique bank relation keys',(){
  final idx=WaffraSmsRelatedEventIndex();
  for(var n=0;n<2000;n++){
   final sms='Purchase Card 20 SAR\nAccount: **1234\nRef: REF'+
      (100000+n).toString();
   final event=WaffraSmsLifecycleEvidence.inspect(sms,sender:'AlRajhi');
   expect(idx.inspectAndRemember(event,nativeId:'native-'+n.toString()),
      WaffraSmsRelatedEvent.none);
  }
  expect(idx.safeHistory().length,256);
  final sanitized=WaffraSmsLifecycleHistoryStore.sanitize(
   idx.safeHistory(),nowMillis:DateTime.now().millisecondsSinceEpoch);
  expect(sanitized.length,256);
 });

 test('M993 history never receives money writer, raw bank SMS or native ACK',(){
  final src=File('lib/waffra_sms_lifecycle_history_store.dart').readAsStringSync();
  final review=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
  expect(src,isNot(contains('saveCaptured(')));
  expect(src,isNot(contains('acknowledgeCommitted(')));
  expect(src,isNot(contains('excludeMessages(')));
  expect(src,contains("waffra_sms_lifecycle_hints_v1_"));
  expect(review,contains('historyOwner==_smsRuleOwnerKey'));
  expect(review,contains('_m630SmsSessionCurrent(smsEpoch)'));
 });
}

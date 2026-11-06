import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M470 #7: excluding an entire sender explicitly asks about the sender',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final clearedSenders=<String>[];'));
  expect(home,contains('groupIds.every(done.contains)'));
  expect(home,contains('هل تريد استبعاد المرسل نفسه أيضًا؟'));
  expect(home,contains('if(block==true&&mounted)'));
  expect(home,contains('WaffraAutoSms.excludeSender(sender)'));
  // The opt-in follows queue acknowledgement, not a bulk-select tap.
  expect(home.indexOf('for(final sender in clearedSenders)'),
   greaterThan(home.indexOf('if(!await WaffraAutoSms.acknowledge(batch))')));
 });

 test('M470 #8: excluded senders have a dedicated restore control',(){
  final home=File('lib/main.dart').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(home,contains('المستبعدون'));
  expect(home,contains("Key('waffra-excluded-senders-list')"));
  expect(home,contains('WaffraAutoSms.excludedSenders()'));
  expect(home,contains('WaffraAutoSms.restoreExcludedSender(sender)'));
  expect(home,contains('إلغاء الاستبعاد'));
  expect(bridge,contains("invokeListMethod<String>('excludedAutoSmsSenders')"));
  expect(bridge,contains("_boolCall('restoreExcludedAutoSmsSender',sender.trim())"));
 });

 test('M470 #9: encrypted, owner-scoped native block stops future SMS',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(store,contains('private const val excludedSendersName ='));
  expect(store,contains('fun excludeSender(context: Context, sender: String)'));
  expect(store,contains('fun restoreExcludedSender(context: Context, sender: String)'));
  expect(store,contains('seal(entries.toString())'));
  expect(store,contains('seal(remaining.toString())'));
  expect(store,contains('editor.remove(queueName).remove(excludedSendersName)'));
  expect(store,contains('isExcludedLocked(context, sender)'));
  expect(store,contains('if (synchronized(mutex) { isExcludedLocked(context, sender) }) continue'));
  expect(activity,contains('"excludeAutoSmsSender" -> result.success('));
  expect(activity,contains('"restoreExcludedAutoSmsSender" -> result.success('));
  final block=store.substring(store.indexOf('fun excludeSender('),
   store.indexOf('fun restoreExcludedSender('));
  expect(block,isNot(contains('commitConfirmedSms')));
  expect(block,isNot(contains('WaffraProductionFinanceAuthorityBinding')));
 });

 test('M470 #10: selecting 500 SMS uses set lookups and bounded acknowledgements',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final idSet=ids.toSet();'));
  expect(home,contains('if(!idSet.contains(item[\'id\'])'));
  expect(home,contains('for(var at=0;at<ids.length;at+=100)'));
  expect(home,contains('ids.skip(at).take(100)'));
  expect(home,contains('ListView.builder('));
  expect(home,contains('final selectedIds=<String>{};'));
 });
}

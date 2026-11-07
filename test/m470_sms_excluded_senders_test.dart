import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M470 #7: excluding an entire sender explicitly asks about the sender',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final clearedSenders=<String>[];'));
  expect(home,contains('groupIds.every(done.contains)'));
  expect(home,contains('هل تريد استبعاد المرسل نفسه أيضًا؟'));
  // #417: explicit Back, No and Exclude choices. Only Exclude persists.
  expect(home,contains("Navigator.pop(dialog,'back')"));
  expect(home,contains("Navigator.pop(dialog,'no')"));
  expect(home,contains("Navigator.pop(dialog,'exclude')"));
  expect(home,contains("if(choice==null||choice=='back'||!ctx.mounted)return;"));
  expect(home,contains("if(choice=='exclude')senderBlockChoices.add(sender);"));
  expect(home,contains('WaffraAutoSms.excludeSender(sender)'));
  // The opt-in follows queue acknowledgement, not a bulk-select tap.
  expect(home,contains('if(!await WaffraAutoSms.excludeMessages(batch))'));
  expect(home.indexOf('for(final sender in clearedSenders.where(senderBlockChoices.contains))'),
   greaterThan(home.indexOf('if(!await WaffraAutoSms.excludeMessages(batch))')));
 });

 test('M470 #8: excluded senders have a dedicated restore control',(){
  final home=File('lib/main.dart').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(home,contains('المستبعدون'));
  expect(home,contains("Key('waffra-excluded-sms-list')"));
  expect(home,contains('messages.length+senders.length+2'));
  expect(home,contains('WaffraAutoSms.excludedMessages()'));
  expect(home,contains('WaffraAutoSms.restoreExcludedMessage(id)'));
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
  // Native message-queue changes run off Android UI thread and respond on it.
  final exclude=activity.substring(
   activity.indexOf('"excludeAutoSmsSender" -> {'),
   activity.indexOf('"restoreExcludedAutoSmsSender" -> {'));
  expect(exclude,contains('smsHistoryExecutor.execute {'));
  expect(exclude,contains('WaffraAutoSmsStore.excludeSender(app, sender)'));
  expect(exclude,contains('runOnUiThread { result.success(excluded) }'));
  final restore=activity.substring(
   activity.indexOf('"restoreExcludedAutoSmsSender" -> {'),
   activity.indexOf('"pendingAutoBankSms" -> {'));
  expect(restore,contains('smsHistoryExecutor.execute {'));
  expect(restore,contains('WaffraAutoSmsStore.restoreExcludedSender(app, sender)'));
  expect(restore,contains('runOnUiThread { result.success(restored) }'));
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

 test('M470 #3/#10 review queue 500-SMS decode never blocks Android UI',(){
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final resume=activity.substring(activity.indexOf('override fun onResume()'),
   activity.indexOf('override fun onRequestPermissionsResult('));
  expect(resume,contains('smsHistoryExecutor.execute {'));
  expect(resume,contains('WaffraAutoSmsStore.pending(app)'));
  expect(resume,contains('runOnUiThread {'));
  final messages=activity.substring(
   activity.indexOf('"excludedAutoSmsSenders" -> {'),
   activity.indexOf('"openMessages" -> {'));
  expect(messages,contains('"pendingAutoBankSms" -> {'));
  expect(messages,contains('"ackAutoBankSms" -> {'));
  expect(messages,contains('smsHistoryExecutor.execute {'));
  expect(messages,contains('WaffraAutoSmsStore.acknowledge(app, ids)'));
  expect(messages,contains('runOnUiThread { result.success(pending) }'));
  expect(messages,contains('SMS_REVIEW_READ_FAILED'));
  expect(messages,contains('runOnUiThread { result.success(acknowledged) }'));
 });
}

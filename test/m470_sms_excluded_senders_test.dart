import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M470 #7: owner chooses between excluding messages and senders',(){
  final home=File('lib/main.dart').readAsStringSync();
  final start=home.indexOf("key:const Key('waffra-sms-bulk-exclude-selected')");
  final end=home.indexOf(' Widget _autoSmsReviewCard(){',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final review=home.substring(start,end);
  // First explicit owner acknowledgement: never delete phone SMS/finance.
  expect(review,contains("final confirmed=await showWaffraDialog<bool>("));
  expect(review,contains('if(confirmed!=true||!ctx.mounted)return;'));
  expect(review,contains('Your phone SMS and saved financial transactions are untouched.'));
  // Exactly one extra decision per bulk selection, not a dialog per sender.
  expect(review,contains("final senderChoice=fullySelectedSenders.isEmpty?'messages':"));
  expect(review,contains('هل تريد استبعاد المرسلين أيضًا؟'));
  expect(review,contains("Navigator.pop(dialog,'back')"));
  expect(review,contains("Navigator.pop(dialog,'messages')"));
  expect(review,contains("Navigator.pop(dialog,'senders')"));
  expect(review,contains("if(senderChoice==null||senderChoice=='back'||!ctx.mounted)return;"));
  expect(review,contains("final senderBlockChoices=senderChoice=='senders'?"));
  // An explicit sender block uses one owner-bound native atomic commit.
  expect(review,contains('WaffraAutoSms.excludeSenders(senderBlockChoices.toList())'));
  expect(review,contains('if(senderBlockChoices.isNotEmpty){'));
  expect(review,contains('if(!await WaffraAutoSms.excludeMessages(batch))'));
  expect(review,contains('if(!failed)for(var at=0;at<remainingMessageIds.length;at+=100)'));
  expect(review,isNot(contains('for(final sender in List<String>.of(senders))')));
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

 test('M470 #10: 1000 SMS selection uses ID sets and bounded exclusion commits',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final idSet=ids.toSet();'));
  expect(home,contains('final selectedIds=<String>{};'));
  expect(home,contains('ListView.builder('));
  expect(home,contains('final blockedIds=<String>{};'));
  expect(home,contains('final remainingMessageIds=ids.where((id)=>!blockedIds.contains(id))'));
  expect(home,contains('if(!failed)for(var at=0;at<remainingMessageIds.length;at+=100)'));
  expect(home,contains('remainingMessageIds.skip(at).take(100)'));
  // No 1000-message bank-facts parsing just to show a confirmation dialog.
  final review=home.substring(home.indexOf("key:const Key('waffra-sms-bulk-exclude-selected')"),
    home.indexOf(' Widget _autoSmsReviewCard(){'));
  final beforeConfirmation=review.split('final confirmed=await showWaffraDialog<bool>(').first;
  expect(beforeConfirmation,isNot(contains('WaffraBankSmsFactsParser.parse(')));
  expect(review,contains('WaffraAutoSms.excludeMessages(batch)'));
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
  expect(messages,contains('result.success(pending)'));
  expect(messages,isNot(contains('runOnUiThread { result.success(pending) }')));
  expect(messages,contains('SMS_REVIEW_READ_FAILED'));
  expect(messages,contains('runOnUiThread { result.success(acknowledged) }'));
 });
}

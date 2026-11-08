import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_auto_sms.dart';

void main(){
 test('M514 incoming money is income, not owned-account transfer',(){
  for(final sms in [
   'حوالة واردة\nالمبلغ: SAR 120.00\nإلى حساب: **8308',
   'حوالة داخلية واردة\nمن: طرف آخر\nمبلغ: SAR 1.00',
   'Incoming Bank Transfer\nAmount: SAR 90.00',
  ]){
   final fact=WaffraBankSmsFactsParser.parse(sms);
   expect(fact.kind,WaffraBankOperationKind.income,reason:sms);
  }
  const outgoing='عملية حوالة مالية صادرة مقبولة\n'
   'خصمت من محفظة: **8308\n'
   'إيبان: **9288\n'
   'القيمة: SAR 882\nالرسوم: SAR 0.58';
  final fact=WaffraBankSmsFactsParser.parse(outgoing);
  expect(fact.kind,WaffraBankOperationKind.transfer);
  expect(fact.sourceSuffix,'8308');
  expect(fact.destinationSuffix,'9288');
  expect(fact.fee,0.58);
  // Generic credit transfer does not prove direction or ownership.
  expect(WaffraBankSmsFactsParser.parse(
   'Credit Transfer via Alinma Bank\nAmount: SAR 1900').kind,
   WaffraBankOperationKind.transfer);
 });

 test('M514 per-button scanned number is never native history total',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('final priorScanned=before?'));
  expect(home,contains('final nowScanned=after?'));
  expect(home,contains('final scanned=(nowScanned-priorScanned)'));
  expect(home,contains('_autoSmsLastRescanScanned=scanned;'));
  expect(home,contains('آخر إعادة فحص: \$_autoSmsLastRescanScanned'));
  expect(home,isNot(contains('إجمالي الرسائل المفحوصة:')));
  expect(home,isNot(contains('عملية غامضة')));
  expect(home,isNot(contains('الرسالة الغامضة')));
  expect(home,isNot(contains('الرسائل الغامضة')));
  expect(home,contains('تحليل هذه الرسالة التي تحتاج مراجعة بالذكاء الاصطناعي؟'));
  expect(home,contains('الرسائل التي تحتاج مراجعة لا تُسجَّل تلقائيًا.'));
 });

 test('M514 excluded queue items use dedicated encrypted fingerprints',(){
  final flutter=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final platform=File('native/WaffraMainActivity.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(flutter,contains("return _boolCall('excludeAutoBankSms',ids);"));
  expect(platform,contains('"excludeAutoBankSms" -> {'));
  expect(native,contains('excludedMessageBucketPrefix'));
  expect(native,contains('fun excludeMessages(context: Context, ids: Set<String>)'));
  expect(native,contains('isExcludedMessageLocked(context, fingerprint)'));
  expect(native,contains('editor.putString(excludedMessageBucketPrefix + bucket,'));
  expect(home,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(home,contains('WaffraAutoSms.excludeMessages([id])'));
  expect(home,contains("kind:'excluded'"));
 });

 test('M514 source-specific account digits, actionable transfer and verified receipt edit',(){
  final home=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  final authority=File('lib/storage/waffra_verified_finance_authority.dart')
    .readAsStringSync();
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
    .readAsStringSync();
  expect(form,contains('onCreateSmsAccount'));
  expect(form,contains('isDestination'));
  expect(home,contains('suggestedLastFour:proposedSuffix'));
  // Destination digits must come only from the destination SMS field;
  // source digits require independent sender-bank agreement.
  expect(home,contains('final proposedSuffix=isDestination?'));
  expect(home,contains('WaffraSmsAccountLearning.suffix4(facts.destinationSuffix):'));
  expect(home,contains('(bank==null||bank==detectedBank)?'));
  expect(home,contains('WaffraSmsAccountLearning.suffix4(facts.sourceSuffix):null;'));
  expect(home,contains("appBar:AppBar(title:const WaffraText('مراجعة حوالة بنكية'))"));
  expect(home,contains('final verifiedMinor=sourceAmount==null?0:'));
  expect(home,contains("'attach-verified-existing-receipt'"));
  expect(authority,contains('Future<WaffraFinanceAuthorityRead> attachReceiptsToExisting('));
  expect(bridge,contains('Future<WaffraFinanceSnapshotState> attachReceiptsToExisting('));
  expect(bridge,contains('return snapshot.store.transaction(() async {'));
  expect(bridge,contains('await vault.attachNewBatch(entryId:entryId,images:frozenImages);'));
 });

 test('M516 native SMS identity determines transfer id, not body-only hash',(){
  final smsA=List<String>.filled(64,'a').join();
  final smsB=List<String>.filled(64,'b').join();
  final first=WaffraAutoSms.transferIdForMessage(smsA);
  final second=WaffraAutoSms.transferIdForMessage(smsB);
  expect(first,'sms-transfer-$smsA');
  expect(first,WaffraAutoSms.transferIdForMessage(smsA));
  expect(second,isNot(first)); // Same body, different sender/time => distinct IDs.
  expect(()=>WaffraAutoSms.transferIdForMessage('invalid'),throwsArgumentError);
  expect(()=>WaffraAutoSms.transferIdForMessage(smsA.toUpperCase()),
   throwsArgumentError);
 });

 test('M516 completed transfer has durable encrypted distinct-from-exclusion ACK',(){
  final flutter=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final platform=File('native/WaffraMainActivity.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  final transfer=home.split('Future<void> _reviewSmsAccountTransfer({').last
   .split('Future<void> _reviewAutoSmsCandidates({').first;
  expect(transfer,contains('WaffraAutoSms.transferIdForMessage(id)'));
  expect(transfer,contains('await api.transfer('));
  expect(transfer,contains('ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id]);'));
  expect(transfer,isNot(contains('WaffraAutoSms.acknowledge([id])')));
  expect(flutter,contains("return _boolCall('ackCompletedTransferAutoBankSms',ids);"));
  expect(platform,contains('"ackCompletedTransferAutoBankSms" -> {'));
  expect(platform,contains('WaffraAutoSmsStore.acknowledgeCompletedTransfer(app, ids)'));
  expect(native,contains('completedTransferBucketPrefix'));
  expect(native,contains('fun acknowledgeCompletedTransfer(context: Context, ids: Set<String>)'));
  expect(native,contains('isCompletedTransferLocked(context, fingerprint)'));
  expect(native,contains('editor.putString(completedTransferBucketPrefix + bucket,'));
  final ownerSwitch=native.split('if (previous != null && previous != owner)').last
   .split('if (owner != null)').first;
  expect(ownerSwitch,contains('key.startsWith(completedTransferBucketPrefix)'));
  expect(ownerSwitch,contains('completedTransferCipherCache.clear()'));
  // No marker may be mistaken for a financial-commit or explicit exclusion.
  final completed=native.split('fun acknowledgeCompletedTransfer(context: Context, ids: Set<String>)').last
   .split('fun acknowledgeCommitted(context: Context, ids: Set<String>)').first;
  expect(completed,isNot(contains('committedBucketPrefix + bucket')));
  expect(completed,isNot(contains('excludedMessageBucketPrefix + bucket')));
 });

 test('M517 excluded SMS list keeps per-message count separate from senders',(){
  final main=File('lib/main.dart').readAsStringSync();
  final dart=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final page=main.split('Future<void> _openExcludedSenders()async{').last
   .split('Future<void> _openAutoSmsInbox()async{').first;
  expect(page,contains('WaffraAutoSms.excludedMessages()'));
  expect(page,contains('WaffraAutoSms.excludedSenders()'));
  expect(page,contains('messages.length+senders.length+2'));
  expect(page,contains('WaffraAutoSms.restoreExcludedMessage(id)'));
  expect(page,contains('رسالة مستبعدة'));
  expect(dart,contains("'excludedAutoSmsMessages'"));
  expect(dart,contains("'restoreExcludedAutoSmsMessage'"));
  expect(activity,contains('"excludedAutoSmsMessages" -> {'));
  expect(activity,contains('"restoreExcludedAutoSmsMessage" -> {'));
  expect(native,contains('fun excludedMessages(context: Context)'));
  expect(native,contains('fun restoreExcludedMessage(context: Context, id: String)'));
  expect(native,contains('excludedMessageInfoBucketPrefix'));
  expect(native,contains('excludedMessageBucketPrefix'));
  expect(native,contains('result.sortedWith('));
  // Backward compatibility: old hash-only markers must appear even
  // without the newly introduced encrypted sender/time metadata.
  expect(native,contains('val info = labels[id]'));
  expect(native,contains('info?.optString("sender") ?: ""'));
  // An exclusion restoration must never manipulate completed finance hashes.
  final restore=native.split('fun restoreExcludedMessage(context: Context, id: String)').last
   .split('// Explicit user sender exclusion').first;
  expect(restore,isNot(contains('committedBucketPrefix + id.take(2)')));
  expect(restore,isNot(contains('completedTransferBucketPrefix + id.take(2)')));
  final ownerSwitch=native.split('if (previous != null && previous != owner)').last
   .split('if (owner != null)').first;
  expect(ownerSwitch,contains('key.startsWith(excludedMessageInfoBucketPrefix)'));
 });

 test('M518 live SMS and history prefer the same sender timestamp',(){
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final history=store.split('fun importConsentMonth(context: Context, maxRead: Int = 500): Int').last
   .split('fun claimReviewNotification(').first;
  expect(receiver,contains('sms.timestampMillis'));
  expect(store,contains('historical: Boolean = false, receivedAt: Long = at'));
  expect(history,contains('"date_sent"'));
  expect(history,contains('val senderTime = if (sentCol >= 0'));
  expect(history,contains('val identityAt = if (senderTime > 946684800000L'));
  // M547: a batch carries Android receipt time separately from the sender
  // timestamp-based identity, and atomically advances only examined rows.
  expect(history,contains('rows.add(HistoricalSmsRow(rowId, at, identityAt,'));
  expect(history,contains('id(row.sender, row.body, row.identityAt)'));
  expect(history,contains('.put("receivedAt", row.receivedAt)'));
  expect(history,contains('"date ASC, _id ASC"'));
  expect(history,contains('nextAt = row.receivedAt'));
  expect(history,contains('nextId = row.rowId'));
  expect(history,contains('.putLong(historyCursorAt, nextAt)'));
  expect(history,contains('.putLong(historyCursorId, nextId)'));
  expect(history,contains('editor.putString(queueName, seal(queue.toString()))'));
  expect(history,contains('if (!editor.commit()) return@synchronized 0'));
  // No timestamp can justify coalescing different native SMS identities.
  final flutter=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(flutter,contains('transferIdForMessage(String fingerprint)'));
 });
}

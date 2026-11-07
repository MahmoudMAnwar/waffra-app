import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main() {
 test('M509 financial categorization does not require the sender to be a known bank',(){
  for(final sender in ['UnlistedFintechXYZ','LocalMerchant','بنك جديد']){
   final body='شراء عبر نقاط البيع\nمبلغ: 236 ريال\nالتاجر: العثيم';
   final facts=WaffraBankSmsFactsParser.parse(body);
   expect(facts.kind,WaffraBankOperationKind.expense);
   final result=WaffraSmsLocalRules.resolve(
    body:body,sender:sender,bankKind:facts.kind);
   expect(result?.category,'بقالة وتموين / سوبرماركت',reason:sender);
   expect(result?.autoPost,false);
  }
 });

 test('M509 native intake is not restricted to a fixed bank sender list',(){
  final source=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(source,contains('val named = senderName.matches(sender.trim())'));
  expect(source,contains('val phoneLike = numericSender.matches(sender.trim())'));
  expect(source,contains('completedFinancialAction.containsMatchIn(safe)'));
  expect(source,contains('return named'));
  expect(source,isNot(contains('return hasFinancialSender')));
  expect(source,contains('return false'));
  expect(source,contains('isExcludedLocked(context, sender)'));
 });

 test('M509 committed markers are owner-bound encrypted hash shards',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('private const val committedBucketPrefix'));
  expect(store,contains('fun acknowledgeCommitted(context: Context, ids: Set<String>)'));
  expect(store,contains('seal(JSONArray(merged.toList()).toString())'));
  expect(store,contains('if (isCommittedLocked(context, fingerprint) ||'));
  expect(store,contains('isExcludedMessageLocked(context, fingerprint) ||'));
  expect(store,contains('isCompletedTransferLocked(context, fingerprint)'));
  expect(store,contains('if (ids.any { !present.contains(it) &&'));
  // On an explicit owner change, the same transaction clears ALL sensitive
  // marker families, not just committed finance hashes. Do not weaken dedup.
  expect(store,contains('if (previous != null && previous != owner) {'));
  expect(store,contains('for (key in prefs.all.keys) {'));
  expect(store,contains('if (key.startsWith(committedBucketPrefix) ||'));
  expect(store,contains('key.startsWith(excludedMessageBucketPrefix) ||'));
  expect(store,contains('key.startsWith(excludedMessageInfoBucketPrefix) ||'));
  expect(store,contains('key.startsWith(completedTransferBucketPrefix)) editor.remove(key)'));
  expect(store,contains('committedCipherCache.clear()'));
  expect(store,contains('excludedMessageCipherCache.clear()'));
  expect(store,contains('completedTransferCipherCache.clear()'));
  expect(store,contains('editor.commit()'));
 });

 test('M509 only completed full scans are restarted by explicit Rescan',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(store,contains('fun restartCompletedHistory(context: Context): Boolean'));
  expect(store,contains('if (!prefs.getBoolean(historyComplete, false))'));
  expect(home,contains("progress?['complete']==true"));
  expect(home,contains('WaffraAutoSms.restartCompletedHistory()'));
  expect(home,contains('await _refreshAutoSmsInbox(importMonth:true)'));
 });

 test('M509 finance-backed ACK is separate from exclude/reject ACK',(){
  final home=File('lib/main.dart').readAsStringSync();
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final nativeMain=File('native/WaffraMainActivity.kt').readAsStringSync();
  final nativeWorker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(home,contains('final toAcknowledgeCommitted=<String>[];'));
  expect(home,contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
  expect(home,contains('WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(home,contains('WaffraAutoSms.excludeMessages([id])'));
  expect(home,contains('WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
  expect(home,isNot(contains('WaffraAutoSms.acknowledge([id])')));
  expect(worker,contains('WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(worker,contains("rule?.builtIn==false"));
  expect(nativeMain,contains('"ackCommittedAutoBankSms" -> {'));
  expect(nativeWorker,contains('"ackCommittedAutoBankSms" -> {'));
  // Native intake can only seal fingerprints after Flutter has confirmed
  // the same body hash exists in the verified SQLCipher financial ledger.
  expect(home,contains('smsHashes.contains(bankSmsHash(body))'));
  expect(worker,contains('finalHashes.contains(fingerprint)'));
 });

 test('M509 duplicate source alone never auto-creates a financial posting',(){
  const body='Card Purchase SAR 75.00 at Panda';
  expect(WaffraSmsLocalRules.resolve(
   body:body,sender:'UnknownSender',
   bankKind:WaffraBankOperationKind.transfer),isNull);
  final source=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(source,contains('if(matched==null||matched.builtIn||!matched.autoPost'));
  expect(source,contains('matched.accountSuffix.isEmpty'));
 });
}

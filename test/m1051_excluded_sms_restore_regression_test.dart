import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M1051 / #784 — source-contract checks for manual restore of owner-excluded
/// SMS without manufacturing an Android finance save.
void main() {
 test('individual restore is one encrypted atomic undo plus review requeue',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final start=native.indexOf('fun restoreExcludedMessage(context: Context');
  final end=native.indexOf('private val completedTransferCipherCache',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final restore=native.substring(start,end);
  expect(restore,contains('if (!isExcludedMessageLocked(context, id))'));
  expect(restore,contains('val label = savedLabels[id]'));
  expect(restore,contains('label.optBoolean("sensitiveOtp", false)'));
  expect(restore,contains('pureVerificationOnly(body)'));
  expect(restore,contains('reviewEligible(sender, body)'));
  expect(restore,contains('isExcludedLocked(context, sender)'));
  expect(restore,contains('isCommittedLocked(context, it)'));
  expect(restore,contains('isCompletedTransferLocked(context, it)'));
  expect(restore,contains('allSourceIds(queue.getJSONObject(index))'));
  expect(restore,contains('queue.length() >= maxCandidates'));
  expect(restore,contains('.put("sourceIds", JSONArray(identities.toList()))'));
  expect(restore,contains('.put("manualRestoreReview", true)'));
  expect(restore,contains('editor.putString(queueName, seal(queue.toString()))'));
  expect(restore,contains('val succeeded = editor.commit()'));
  expect(restore,isNot(contains('contentResolver.delete(')));
  expect(restore,isNot(contains('acknowledgeCommitted(')));
 });

 test('native review exposes override only from encrypted pending owner row',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final pending=native.substring(
   native.indexOf('fun pending(context: Context):'),
   native.indexOf('fun markBackgroundSmsReviewed(',native.indexOf('fun pending(context: Context):')));
  expect(pending,contains('"manualRestoreReview" to row.optBoolean("manualRestoreReview", false)'));
  expect(native,contains('.put("identityAt", row.optLong("identityAt",'));
 });

 test('explicitly restored row cannot be ACKed by a learned exclude rule',(){
  final main=File('lib/main.dart').readAsStringSync();
  final begin=main.indexOf('Map<String,Object?> waffraM632ClassifySmsQueue(');
  final end=main.indexOf('List<String> splitBankMessages(',begin);
  final classify=main.substring(begin,end);
  expect(classify,contains("candidate['manualRestoreReview']!=true"));
  expect(classify,contains("candidate['manualRestoreReview']==true&&local?['kind']=='excluded'"));
  expect(classify,contains('local=null;'));
  expect(classify,contains("if(local['kind']=='excluded'){"));
 });

 test('both restore actions refresh the same live review and real provider',(){
  final screen=File('lib/waffra_home_sms_management.part.dart')
   .readAsStringSync();
  final message=screen.substring(
   screen.indexOf('WaffraAutoSms.restoreExcludedMessage(id)')-120,
   screen.indexOf('WaffraAutoSms.restoreExcludedMessage(id)')+700);
  expect(message,contains('await _refreshAutoSmsInbox();'));
  expect(message,contains('_autoSmsPending.any((row)=>row[\'id\']==id)'));
  final sender=screen.substring(
   screen.indexOf('WaffraAutoSms.restoreExcludedSender(sender)')-120,
   screen.indexOf('WaffraAutoSms.restoreExcludedSender(sender)')+450);
  expect(sender,contains('await _rescanAutoSmsInbox(feedbackContext:ctx);'));
  final scan=File('lib/waffra_home_sms_rescan.part.dart').readAsStringSync();
  expect(scan,contains('await WaffraAutoSms.recoverRecentlyMissedSmsChecked();'));
 });
}

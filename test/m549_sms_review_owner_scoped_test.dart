import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M549 any sender enters review-only queue, with independent finance safety',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final eligible=native.substring(native.indexOf('fun reviewEligible('),
   native.indexOf('fun qualifies('));
  expect(eligible,contains('sender.isNotBlank()'));
  expect(eligible,contains('body.isNotBlank()'));
  expect(eligible,isNot(contains('institutionalSender')));
  final importer=native.substring(native.indexOf('fun importConsentMonth('));
  expect(importer,contains('reviewEligible(row.sender, row.body)'));
  final live=native.substring(native.indexOf('fun offer('),
   native.indexOf('fun pending('));
  expect(live,contains('if (!reviewEligible(sender, body)) return false'));
  expect(live,contains('isExcludedLocked(context, sender)'));
  expect(live,contains('isCommittedLocked(context, fingerprint)'));
  expect(live,contains('isCompletedTransferLocked(context, fingerprint)'));
  expect(live,contains('val masked = if (sensitive)'));
  expect(importer,contains('val masked = if (sensitive)'));
  expect(native,contains('private const val maxCandidates = 1000'));
 });

 test('M549 sender exclusion drops queue and previous labelled exclusions atomically',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final section=native.substring(native.indexOf('fun excludeSenders('),
   native.indexOf('fun restoreExcludedSender('));
  expect(section,contains('val previous = readExcluded(context)'));
  expect(section,contains('for (i in 0 until current.length())'));
  expect(section,contains('excludedMessageInfoBucketPrefix'));
  expect(section,contains('excludedMessageBucket(context, sampleId)'));
  expect(section,contains('editor.remove(excludedMessageBucketPrefix + shard)'));
  expect(section,contains('if (keptLabels.isEmpty()) editor.remove(key)'));
  expect(section,contains('val saved = editor.commit()'));
  expect(section,isNot(contains('committedBucketPrefix')));
  expect(section,isNot(contains('completedTransferBucketPrefix')));
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(activity,contains('"excludeAutoSmsSenders" ->'));
  expect(activity,contains('WaffraAutoSmsStore.excludeSenders(app, names)'));
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(bridge,contains("_boolCall('excludeAutoSmsSenders',senders)"));
 });

 test('M549 select 1000, no sender confirmation storm, no per-message sender receipts',(){
  final main=readWaffraMainSourceForContracts();
  final review=main.substring(main.indexOf(' Future<void> _openAutoSmsInbox()async{'),
   main.indexOf(' Widget _autoSmsReviewCard(){'));
  expect(review,contains('waffra-sms-select-all-visible'));
  expect(review,contains('waffra-sms-bulk-exclude-selected'));
  expect(review,contains("final senderChoice=fullySelectedSenders.isEmpty?'messages':"));
  expect(review,contains('final blockedIds=<String>{};'));
  expect(review,contains('WaffraAutoSms.excludeSenders(senderBlockChoices.toList())'));
  expect(review,contains('if(!failed)for(var at=0;at<remainingMessageIds.length;at+=100)'));
  expect(review,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(review,contains("blockedIds.contains(row['id'])"));
  expect(review,isNot(contains('for(final sender in List<String>.of(senders))')));
 });

 test('M549 1000-message bulk confirm never parses SMS bodies on the UI isolate',(){
  final main=readWaffraMainSourceForContracts();
  final begin=main.indexOf('waffra-sms-bulk-exclude-selected');
  final end=main.indexOf('final confirmed=await showWaffraDialog<bool>',begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final preConfirm=main.substring(begin,end);
  expect(preConfirm,contains('final ids=selectedIds.toList(growable:false);'));
  expect(preConfirm,isNot(contains('WaffraBankSmsFactsParser.parse(')));
  expect(preConfirm,isNot(contains('likelyFinancial')));
  expect(main,contains('قد تتضمن الرسائل معاملات مالية؛ راجع اختيارك.'));
  expect(main,contains('Your phone SMS and saved financial transactions are untouched.'));
 });

 test('M549 completed rescan dims unless fresh provider rows or unfinished history',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(native,contains('private fun hasUnseenInboxRows('));
  expect(native,contains('"rescanNeeded" to (waiting in 0 until maxCandidates'));
  expect(native,contains('hasUnseenInboxRows(context, prefs)'));
  expect(native,contains('historyCursorAt'));
  expect(native,contains('historyCursorId'));
  expect(native,contains('isExcludedMessageLocked(context, fingerprint)'));
  final main=readWaffraMainSourceForContracts();
  expect(main,contains("_autoSmsProgress['rescanNeeded']==true"));
  expect(main,contains('onPressed:canRescan?'));
  expect(main,contains('await _refreshAutoSmsInbox(importMonth:true);'));
 });

 test('M549 all sender lists still hide actual Android messages from deletion',(){
  final review=readWaffraMainSourceForContracts();
  expect(review,contains('Your phone SMS and saved financial transactions are untouched.'));
  expect(review,isNot(contains('deleteAndroidSms')));
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(native,contains('context.contentResolver.query(Uri.parse("content://sms/inbox")'));
  expect(native,isNot(contains('contentResolver.delete(')));
 });
}

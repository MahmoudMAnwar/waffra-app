import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M1052 / #786. Synthetic examples only; no live sender, OTP secret,
/// Android inbox or private encrypted archive is read by these tests.
void main() {
 test('M1052 compact Saudi POS stays an expense and never a learned exclusion',(){
  const examples=<String>[
   'شراء PoS عبر:7678 مدى-مدى باي بـ SAR 83 لدى KUDU RO06 11:02 20/11/26',
   'شراء PoS عبر:7678 مدى-مدى باي بـ SAR 37 لدى SARA AYED 15:56 20/11/26',
  ];
  for(final sms in examples){
   final facts=WaffraBankSmsFactsParser.parse(sms);
   expect(facts.kind,WaffraBankOperationKind.expense);
   expect(WaffraBankSmsFactsParser.reviewSuggestedKind(body:sms),'expense');
   final rule=WaffraSmsLocalRules.resolveSpecial(
    body:sms,sender:'AlRajhiBank',
    bankKind:facts.kind);
   expect(rule?.resolvedKind,isNot('excluded'));
  }
 });

 test('M1052 real outgoing completed transfer stays owner-reviewable',(){
  const sms='حوالة داخلية صادرة بـ SR 30 من 9288 لـ 5077 في 20/11/26 20:44';
  final facts=WaffraBankSmsFactsParser.parse(sms);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(body:sms),'expense');
  expect(WaffraSmsLocalRules.resolveSpecial(
   body:sms,sender:'AlRajhiBank',bankKind:facts.kind)?.resolvedKind,
   isNot('excluded'));
 });

 test('M1052 amount-bearing OTP is only a challenge; never a completed transfer',(){
  const sms='رمز مؤقت:5265 ل: تحويل داخلي - التطبيق المبلغ:SAR 30.00';
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(sms),isTrue);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(body:sms),isNull);
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final classifier=native.substring(
   native.indexOf('private val authorizationChallenge = Regex('),
   native.indexOf('private fun recordPureOtpExclusionLocked(', 
    native.indexOf('private val authorizationChallenge = Regex(')));
  expect(classifier,contains('authorizationChallenge.containsMatchIn(body)'));
  expect(classifier,contains('completedBankHeadline.containsMatchIn(body)'));
  expect(classifier,contains('completedFinancialAction.containsMatchIn(body)) return false'));
  expect(native,contains('if (pureVerificationOnly(body)) {'));
  expect(native,contains('recordPureOtpExclusionLocked('));
 });

 test('M1052 legacy undo verifies original identity outside lock then commits once',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final readback=native.substring(
   native.indexOf('private fun findOriginalExcludedSms('),
   native.indexOf('fun restoreExcludedMessage(context: Context'));
  expect(readback,contains('content://sms/inbox'));
  expect(readback,contains('PackageManager.PERMISSION_GRANTED'));
  expect(readback,contains('id(sender, body, identityAt) != fingerprint'));
  expect(readback,contains('id(sender, body, received) != fingerprint'));
  expect(readback,contains('Triple("", "otp_protected", identityAt)'));
  final restore=native.substring(
   native.indexOf('fun restoreExcludedMessage(context: Context'),
   native.indexOf('private val completedTransferCipherCache'));
  expect(restore,contains('val snapshot = synchronized(mutex)'));
  expect(restore,contains('val original = if (needsProvider) try {'));
  expect(restore,contains('return synchronized(mutex)'));
  expect(restore.indexOf('val original = if (needsProvider)'),
   lessThan(restore.indexOf('return synchronized(mutex)')));
  expect(restore,contains('signedInOwnerHash(context) != snapshot.first'));
  expect(restore,contains('if (!isExcludedMessageLocked(context, id))'));
  expect(restore,contains('label.optBoolean("sensitiveOtp", false)'));
  expect(restore,contains('pureVerificationOnly(body)'));
  expect(restore,contains('isExcludedLocked(context, sender)'));
  expect(restore,contains('isCommittedLocked(context, it)'));
  expect(restore,contains('isCompletedTransferLocked(context, it)'));
  expect(restore,contains('queue.length() >= maxCandidates'));
  expect(restore,contains('allSourceIds(queue.getJSONObject(index))'));
  expect(restore,contains('.put("manualRestoreReview", true)'));
  expect(restore,contains('editor.putString(queueName, seal(queue.toString()))'));
  expect(restore,contains('val succeeded = editor.commit()'));
  expect(restore,isNot(contains('contentResolver.delete(')));
  expect(restore,isNot(contains('commitConfirmedSms(')));
 });

 test('M1052 all native acquisition paths share exclusion and offer filters',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final live=native.substring(
   native.indexOf('fun offer(context: Context'),
   native.indexOf('fun pending(context: Context'));
  expect(live,contains('reviewEligible(sender, body)'));
  expect(live,contains('isExcludedMessageLocked(context, fingerprint)'));
  expect(live,contains('pureVerificationOnly(body)'));
  final history=native.substring(
   native.indexOf('fun importConsentMonth(context: Context'),
   native.indexOf('    /** Claim each review notification once;'));
  expect(history,contains('reviewEligible(row.sender, row.body)'));
  expect(history,contains('pureVerificationOnly(row.body)'));
  final recent=native.substring(
   native.indexOf('fun recoverRecentlyMissedSms('),
   native.indexOf('fun importConsentMonth(context: Context'));
  expect(recent,contains('reviewEligible(sender, body)'));
  expect(recent,contains('offer(context, sender, body, identityAt,'));
 });

 test('M1052 excluded sheet displays true details and specific undo outcome',(){
  final ui=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  final sheet=ui.substring(ui.indexOf('Future<void> _openExcludedSenders()'),
   ui.indexOf('/// Real notifications:',ui.indexOf('Future<void> _openExcludedSenders()')));
  expect(sheet,contains('WaffraAutoSms.excludedMessageDetails(id)'));
  expect(sheet,contains('WaffraAutoSms.restoreExcludedMessage(id)'));
  expect(sheet,contains('WaffraAutoSms.restoreExcludedSender(sender)'));
  expect(sheet,contains('await _refreshAutoSmsInbox()'));
  expect(sheet,contains('original=(details?'));
  expect(sheet,contains("details?['status']=='otp_protected'"));
  expect(sheet,contains("details?['status']=='unavailable'"));
  expect(sheet,contains('if(restored)messages.removeWhere('));
  expect(sheet,contains('if(visible)snackSuccess('));
 });
}

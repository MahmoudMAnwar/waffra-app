import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M1053 / #788: synthetic contracts only. Phone-specific source identity
/// and encrypted account data must be verified on a real signed Android APK.
void main() {
 test('M1053 bank POS and completed outbound remain safe review candidates',(){
  const messages=<String>[
   'شراء PoS عبر:7678 مدى-مدى باي بـ SAR 83 لدى KUDU RO06 11:02 20/11/26',
   'شراء PoS عبر:7678 مدى-مدى باي بـ SAR 37 لدى SARA AYED 15:56 20/11/26',
   'حوالة داخلية صادرة بـ SR 30 من 9288 لـ 5077 في 20/11/26 20:44',
  ];
  for(final body in messages){
   final facts=WaffraBankSmsFactsParser.parse(body);
   expect(facts.kind,WaffraBankOperationKind.expense,reason:body);
   expect(WaffraBankSmsFactsParser.reviewSuggestedKind(body:body),'expense');
   expect(WaffraSmsLocalRules.resolveSpecial(
    body:body,sender:'AlRajhiBank',bankKind:facts.kind)?.resolvedKind,
    isNot('excluded'));
  }
 });

 test('M1053 amount-bearing transfer authorization still protects OTP',(){
  const body='رمز مؤقت:5265 ل: تحويل داخلي - التطبيق المبلغ:SAR 30.00';
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(body:body),isNull);
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(native,contains('if (pureVerificationOnly(body)) {'));
  expect(native,contains('recordPureOtpExclusionLocked('));
  expect(native,contains('Triple("", "otp_protected", identityAt)'));
 });

 test('M1053 exact original always wins; one same-receipt fallback only',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final lookup=native.substring(
   native.indexOf('private fun findOriginalExcludedSms('),
   native.indexOf('fun restoreExcludedMessage(context: Context'));
  expect(lookup,contains('context.checkSelfPermission(Manifest.permission.READ_SMS)'));
  expect(lookup,contains('if (sender != expectedSender) continue'));
  expect(lookup,contains('val exactFingerprint ='));
  expect(lookup,contains('id(sender, body, identityAt) != fingerprint'));
  expect(lookup,contains('id(sender, body, received) != fingerprint'));
  expect(lookup,contains('kotlin.math.abs(received - receivedAt) > 1500L'));
  expect(lookup,contains('if (near.size < 2) near.add('));
  expect(lookup,contains('return exact ?: if (near.size == 1) near.single() else null'));
  expect(lookup,contains('completedBankHeadline.containsMatchIn(body)'));
  expect(lookup,isNot(contains('contentResolver.delete(')));
 });

 test('M1053 distinct Android ID does not revive confirmed money or unblock sender',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final undo=native.substring(
   native.indexOf('fun restoreExcludedMessage(context: Context'),
   native.indexOf('private val completedTransferCipherCache'));
  expect(undo,contains('signedInOwnerHash(context) != snapshot.first'));
  expect(undo,contains('val restoredId = if (needsProvider)'));
  expect(undo,contains('isExcludedMessageLocked(context, restoredId)'));
  expect(undo,contains('val identities = linkedSetOf(id, restoredId)'));
  expect(undo,contains('isCommittedLocked(context, it)'));
  expect(undo,contains('isCompletedTransferLocked(context, it)'));
  expect(undo,contains('isExcludedLocked(context, sender)'));
  expect(undo,contains('queue.length() >= maxCandidates'));
  expect(undo,contains('.put("id", restoredId)'));
  expect(undo,contains('.put("restoredFromExcludedId", id)'));
  expect(undo,contains('.put("manualRestoreReview", true)'));
  expect(undo,contains('val succeeded = editor.commit()'));
  final review=native.substring(
   native.indexOf('fun pending(context: Context):'),
   native.indexOf('fun markBackgroundSmsReviewed('));
  expect(review,contains('"restoredFromExcludedId" to row.optString('));
  final sheet=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  expect(sheet,contains("row['id']==id||row['restoredFromExcludedId']==id"));
 });

 test('M1053 owner rescan reports native hidden reasons instead of false zero',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final recovery=native.substring(native.indexOf('fun recoverRecentlyMissedSms('),
   native.indexOf('fun importConsentMonth('));
  for(final reason in const [
   'notFinancial','verification','senderBlocked','messageExcluded',
   'alreadyCommitted','alreadyPending','intakeRejected'
  ]){
   expect(recovery,contains('"$reason"'),reason:reason);
  }
  expect(recovery,contains('"skipReasons" to skipped.toMap()'));
  expect(recovery,contains('"senderSkipReasons" to senderSummary'));
  expect(recovery,contains('ownerAtStart != signedInOwnerHash(context)'));
  expect(recovery,contains('offer(context, sender, body, identityAt,'));
  expect(recovery,isNot(contains('remove(historyCursorAt)')));
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(bridge,contains("'skipReasons':reasons"));
  expect(bridge,contains("'senderSkipReasons':bySender"));
  final refresh=File('lib/waffra_home_sms_rescan.part.dart').readAsStringSync();
  expect(refresh,contains("recovery['skipReasons']"));
  expect(refresh,contains("recovery['senderSkipReasons']"));
  expect(refresh,contains("skipped('senderBlocked')"));
  expect(refresh,contains("skipped('messageExcluded')"));
  expect(refresh,contains("if(diagnostic.isNotEmpty)snack("));
 });

 test('M1053 no new money writer or source deletion by diagnostic/undo paths',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final undo=native.substring(native.indexOf('fun restoreExcludedMessage(context: Context'),
   native.indexOf('private val completedTransferCipherCache'));
  final recovery=native.substring(native.indexOf('fun recoverRecentlyMissedSms('),
   native.indexOf('fun importConsentMonth('));
  for(final section in [undo,recovery]){
   expect(section,isNot(contains('contentResolver.delete(')));
   expect(section,isNot(contains('commitConfirmedSms(')));
   expect(section,isNot(contains('acknowledgeCommitted(')));
  }
 });
}

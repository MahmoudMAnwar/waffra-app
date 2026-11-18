import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

/// M1016 / #732: synthetic-only native intake contract. No Android SMS,
/// account number, OTP or live phone data is imported into this test.
void main(){
 test('M1016 source gate rejects non-financial text before encrypted enqueue',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final predicate=native.split('fun reviewEligible(sender: String, body: String): Boolean {')[1]
   .split('    fun qualifies(sender: String, body: String): Boolean {')[0];
  expect(predicate,contains('if (sender.isBlank() || sender.trim().length > 100 ||'));
  expect(predicate,contains('body.isBlank() || body.length > 1600) return false'));
  expect(predicate,contains('if (pureVerificationOnly(body)) return true'));
  expect(predicate,contains('nonTransactionPromotion.containsMatchIn(body)'));
  expect(predicate,contains('!completedFinancialAction.containsMatchIn(body)'));
  expect(predicate,contains('return qualifies(sender, body) ||'));
  expect(predicate,contains('unknownFinancialKind(sender, body) != null'));
  expect(predicate,isNot(contains('return true;')));
  final live=native.split('    fun offer(context: Context, sender: String, body: String, at: Long,')[1]
   .split('    fun pending(context: Context):')[0];
  expect(live,contains('if (!reviewEligible(sender, body)) return false'));
  expect(live.indexOf('if (!reviewEligible(sender, body)) return false'),
    lessThan(live.indexOf('val queue = read(context)')));
  expect(live,contains('if (pureVerificationOnly(body)) {'));
  expect(live,contains('recordPureOtpExclusionLocked('));
  expect(live,contains('if (queue.length() >= maxCandidates)'));
  expect(live,contains('save(context, collapseQueuedMultipartLocked(context, queue))'));
  expect(live,contains('if (fingerprint in allSourceIds(queue.getJSONObject(i)))'));
  // M1038: only unconfirmed bank SMS fragments are combined; OTP guard remains before offer.
  expect(live,isNot(contains('commitConfirmedSms(')));
  expect(live,isNot(contains('FirebaseFirestore')));
 });

 test('M1016 historical and live share filter, with OTP 30-day exclusion',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final scan=native.split('    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {')[1]
   .split('    /** Claim each review notification once;')[0];
  expect(scan,contains('reviewEligible(row.sender, row.body)'));
  expect(scan,contains('if (pureVerificationOnly(row.body)) {'));
  expect(scan,contains('deniedOtpByShard'));
  // Historical OTP labels are loaded through the existing encrypted shard
  // helper; this is not a direct bucket getter. Preserve the shared IDs,
  // label and timestamp writes rather than asserting a nonexistent symbol.
  expect(scan,contains('excludedMessageInfo(context, fingerprint)'));
  expect(scan,contains('for ((shard, ids) in deniedOtpByShard) {'));
  expect(scan,contains('editor.putString(excludedMessageInfoBucketPrefix + shard,'));
  expect(scan,isNot(contains('notifyReview(')));
  expect(native,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
 });

 test('M1016 promotional amount alone is not a posted transaction',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(native,contains('private val nonTransactionPromotion = Regex('));
  expect(native,contains('completedFinancialAction.containsMatchIn(body)'));
  expect(native,contains('!completedFinancialAction.containsMatchIn(body)'));
  // Financial evidence must not require a sender to be on a bank allowlist.
  final predicate=native.split('fun reviewEligible(sender: String, body: String): Boolean {')[1]
    .split('    fun qualifies(sender: String, body: String): Boolean {')[0];
  expect(predicate,isNot(contains('brand.matches(sender)')));
  expect(predicate,isNot(contains('institutionalSender.matches(sender)')));
  expect(native,contains('private val numericSender = Regex('));
  expect(native,contains('completedFinancialAction.containsMatchIn(safe)'));
  expect(native,contains('money.containsMatchIn(safe)'));
  expect(native,contains('digits.containsMatchIn(safe)'));
 });

 test('M1016 raw mixed-money plus OTP remains non-posting review',(){
  const cases=<String>[
   'تم خصم 85 ريال من حسابك. رمز التحقق 123456',
   'حوالة صادرة بمبلغ 140 ريال. رمز التحقق 987654',
   'Purchase approved for SAR 45.50. OTP 123456',
  ];
  for(final body in cases){
   expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
  }
  final source=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(source,contains('!completedFinancialAction.containsMatchIn(body)'));
  expect(source,contains('val masked = if (sensitive) redactMixedOtpSecrets(body) else body.trim()'));
  expect(source,contains('.put("sensitiveOtp", sensitive)'));
 });

 test('M1016 receiver never blocks Android broadcast or writes money',(){
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(receiver,contains('SMS_RECEIVED_ACTION'));
  expect(receiver,contains('WaffraAutoSmsStore.offer('));
  expect(receiver,contains('WaffraAutoSmsWorker.enqueue(context)'));
  expect(worker,contains('waffraAutoSmsBackgroundEntrypoint')); // Dart background entrypoint
  expect(receiver,isNot(contains('commitConfirmedSms(')));
 });
}

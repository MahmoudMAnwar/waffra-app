import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M981 #685: synthetic history/live parity. Raw provider SMS and owner
/// credential data are NEVER imported into tests or GitHub.
void main() {
  test('M981 live and historical native intake use the same pure-OTP gate',
      () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final live=native.substring(
      native.indexOf('    fun offer(context: Context, sender: String, body: String, at: Long,'),
      native.indexOf('    fun pending(context: Context):'));
    final history=native.substring(
      native.indexOf('    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {'),
      native.indexOf('    /** Claim each review notification once;'));
    expect(live,contains('if (pureVerificationOnly(body)) {'));
    expect(history,contains('if (pureVerificationOnly(row.body)) {'));
    final historyOtp=history.indexOf('if (pureVerificationOnly(row.body))');
    final historyMasked=history.indexOf('val masked = if (sensitive)');
    final historyQueue=history.indexOf('queue.put(JSONObject().put("id", fingerprint)');
    expect(historyOtp,greaterThanOrEqualTo(0));
    expect(historyOtp,lessThan(historyMasked));
    expect(historyOtp,lessThan(historyQueue));
    expect(history,contains('!isCommittedLocked(context, fingerprint)'));
    expect(history,contains('!isExcludedMessageLocked(context, fingerprint)'));
    expect(history,contains('!isCompletedTransferLocked(context, fingerprint)'));
    expect(history,contains('ownerAtStart != signedInOwnerHash(context)'));
    expect(live,contains('recordPureOtpExclusionLocked('));
  });

  test('M981 historical OTP denial and its cursor use ONE encrypted commit',
      () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final start=native.indexOf(
      '    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {');
    final end=native.indexOf('    /** Claim each review notification once;',start);
    final history=native.substring(start,end);
    expect(history,contains('val deniedOtpByShard = mutableMapOf<String, MutableSet<String>>()'));
    expect(history,contains('val otpLabelsByShard ='));
    expect(history,contains('excludedMessageBucket(context, fingerprint)'));
    expect(history,contains('excludedMessageInfo(context, fingerprint)'));
    expect(history,contains('.put("id", fingerprint)'));
    expect(history,contains('.put("sender", row.sender.trim().take(100))'));
    expect(history,contains('.put("receivedAt", row.receivedAt)'));
    expect(history,contains('.put("excludedAt", System.currentTimeMillis())'));
    expect(history,contains('for ((shard, ids) in deniedOtpByShard) {'));
    expect(history,contains('editor.putString(excludedMessageBucketPrefix + shard,'));
    expect(history,contains('editor.putString(excludedMessageInfoBucketPrefix + shard,'));
    expect(history,contains('editor.putLong(historyCursorAt, nextAt)'));
    expect(history,contains('editor.putLong(historyCursorId, nextId)'));
    expect(history,contains('.putLong(historyCursorAt, nextAt)'));
    expect(history,contains('.putLong(historyCursorId, nextId)'));
    expect(history,contains('.putLong(historyScannedCount, previousExamined + examined)'));
    expect(history,contains('.putLong(historyAddedCount, previousAdded + accepted)'));
    expect(history,contains('.putBoolean(historyComplete, complete)'));
    expect(RegExp(r'\beditor\.commit\(\)').allMatches(history).length,1);
    expect(history,contains('if (!editor.commit()) return@synchronized 0'));
    expect(history,contains('excludedMessageCipherCache.clear()'));
    expect(history.indexOf('if (!editor.commit()) return@synchronized 0'),
      lessThan(history.indexOf('excludedMessageCipherCache.clear()')));
    expect(history,isNot(contains('recordPureOtpExclusionLocked(')),
      reason:'No per-message fsync or encrypted queue writes on history');
  });

  test('M981 historical OTP does not advance on failure or pretend it was reviewed',
      () {
    final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final start=native.indexOf(
      '    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {');
    final end=native.indexOf('    /** Claim each review notification once;',start);
    final history=native.substring(start,end);
    final scan=history.substring(history.indexOf('for (row in rows.take(maxRead))'));
    final otp=scan.substring(scan.indexOf('if (pureVerificationOnly(row.body))'),
      scan.indexOf('val complete = !stoppedForCapacity'));
    expect(otp,contains('existingIds.add(fingerprint)'));
    expect(otp,contains('} else {'));
    expect(otp,contains('accepted++'));
    expect(otp.indexOf('accepted++'),
      greaterThan(otp.indexOf('} else {')));
    expect(history,contains('} catch (_: Exception) {\n                // Never overwrite earlier ciphertext or advance a failed scan.'));
    expect(history,contains('if (!editor.commit()) return@synchronized 0'));
    expect(native,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
    expect(history,isNot(contains('notifyReview(')));
    expect(history,isNot(contains('.put("body", row.body)')));
    expect(history,contains('.put("body", masked)'));
  });

  test('M981 mixed actual money + code is not mislabeled as pure OTP',(){
    for(final body in const <String>[
      'تم خصم 85 ريال من حسابك. رمز التحقق 123456',
      'حوالة صادرة بمبلغ 140 ريال. رمز التحقق 987654',
      'Payment completed SAR 75.00. Your verification code is 123456',
      'Purchase approved for SAR 45.50. OTP 123456',
    ]){
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
      final chosen=WaffraSmsLocalRules.resolveSpecial(
        body:body,sender:'MyBank',
        bankKind:WaffraBankSmsFactsParser.parse(body).kind,
        nativeSensitiveOtp:true,
        matchedRules:WaffraSmsLocalRules.matchAllFourKinds(
          body:body,sender:'MyBank'));
      expect(chosen?.resolvedKind,isNot('excluded'),reason:body);
    }
  });

  test('M981 thousand synthetic incoming historic messages keep four-way safety',(){
    final messages=List<String>.generate(1000,(i)=>switch(i%5){
      0=>'رمز التحقق: ${100000+i} لتطبيق جديد',
      1=>'Your verification code is ${100000+i} for NewApp',
      2=>'تم خصم 85 ريال من حسابك. رمز التحقق ${100000+i}',
      3=>'تم إيداع راتب 7000 ريال في حسابك',
      _=>'حوالة صادرة بمبلغ 140 ريال',
    });
    var pureExclusions=0,retained=0;
    for(var i=0;i<messages.length;i++){
      final body=messages[i];
      final facts=WaffraBankSmsFactsParser.parse(body);
      final matches=WaffraSmsLocalRules.matchAllFourKinds(
        body:body,sender:'SyntheticSender');
      final special=WaffraSmsLocalRules.resolveSpecial(
        body:body,sender:'SyntheticSender',bankKind:facts.kind,
        matchedRules:matches);
      if(i%5<2){
        expect(special?.resolvedKind,'excluded',reason:'historical row $i');
        pureExclusions++;
      }else{
        expect(special?.resolvedKind,isNot('excluded'),
          reason:'financial historic row $i');
        retained++;
      }
    }
    expect(pureExclusions,400);
    expect(retained,600);
  });
}

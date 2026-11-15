import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M979/#683: original SMS never uploaded. This checks Flutter's executable
/// special-rule parity and the native enqueue/exclusion source boundary.
void main() {
  test('M979 new-app Arabic and English OTP stay excluded by app rule engine',
      () {
    const samples = <String>[
      'رمزك هو 483926 لتفعيل تطبيق جديد',
      'رمز التحقق: ١٢٣٤٥٦ الخاص بتطبيق جديد',
      'رمز تفعيل الحساب 112233 لتطبيق جديد',
      'رمز مؤقت ٤٥٦٧٨٩ للدخول إلى خدمة',
      'Your login code is 481923 for NewApp',
      'Your verification code is 123456 for NewApp',
      'OTP 829105 for a newly installed app',
    ];
    for (final body in samples) {
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(body), isTrue,
          reason: body);
      final facts = WaffraBankSmsFactsParser.parse(body);
      final outcome = WaffraSmsLocalRules.resolveSpecial(
        body: body, sender: 'UnfamiliarNewApp', bankKind: facts.kind);
      expect(outcome?.resolvedKind, 'excluded', reason: body);
    }
  });

  test('M979 mixed settled money and verification never auto-exclude', () {
    const messages = <String>[
      'تم خصم 85 ريال من حسابك. رمز التحقق 123456',
      'حوالة صادرة بمبلغ 140 ريال. رمز التحقق 987654',
      'Payment completed SAR 75.00. Your verification code is 123456',
      'Purchase approved for SAR 45.50. OTP 123456',
    ];
    for (final body in messages) {
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(body), isTrue,
          reason: body);
      final facts = WaffraBankSmsFactsParser.parse(body);
      final outcome = WaffraSmsLocalRules.resolveSpecial(
        body: body, sender: 'Bank', bankKind: facts.kind,
        nativeSensitiveOtp: true);
      expect(outcome?.resolvedKind, isNot('excluded'), reason: body);
    }
  });

  test('M979 native intake blocks pure OTP before queue capacity or notify',
      () {
    final native = File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final safe = native.substring(
      native.indexOf('private fun pureVerificationOnly('),
      native.indexOf('private fun recordPureOtpExclusionLocked('));
    expect(safe, contains('otp.containsMatchIn(body)'));
    expect(safe, contains('explicitOtpToken.containsMatchIn(body)'));
    expect(safe, contains('private val explicitOtpToken = Regex('));
    expect(safe, contains('!completedFinancialAction.containsMatchIn(body)'));
    expect(safe, contains('action.containsMatchIn(body) && money.containsMatchIn(body)'));
    final offer = native.substring(
      native.indexOf('    fun offer(context: Context, sender: String, body: String, at: Long,'),
      native.indexOf('    fun pending(context: Context):',));
    final afterDedup = offer.indexOf('isCommittedLocked(context, fingerprint)');
    final auto = offer.indexOf('if (pureVerificationOnly(body))');
    final persisted = offer.indexOf('recordPureOtpExclusionLocked(');
    final exit = offer.indexOf('return@synchronized false', persisted);
    final cap = offer.indexOf('if (queue.length() >= maxCandidates)');
    final candidate = offer.indexOf('queue.put(JSONObject()');
    final notify = offer.indexOf('if (result && !historical)');
    expect(afterDedup, greaterThanOrEqualTo(0));
    expect(afterDedup, lessThan(auto));
    expect(auto, lessThan(persisted));
    expect(persisted, lessThan(exit));
    expect(exit, lessThan(cap));
    expect(cap, lessThan(candidate));
    expect(candidate, lessThan(notify));
    expect(offer, contains('!enabled(context) || isExcludedLocked(context, sender)'));
    expect(offer, contains('isExcludedMessageLocked(context, fingerprint)'));
    expect(offer, contains('isCompletedTransferLocked(context, fingerprint)'));
    expect(offer, contains('val masked = if (sensitive) body.trim().replace('));
  });

  test('M979 native exclusion persists only encrypted fingerprint and safe label',
      () {
    final native = File('native/WaffraAutoSmsStore.kt').readAsStringSync();
    final start = native.indexOf('private fun recordPureOtpExclusionLocked(');
    final end = native.indexOf('// M437: Unknown-finance lookup', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = native.substring(start, end);
    expect(body, contains('excludedMessageBucket(context, fingerprint)'));
    expect(body, contains('excludedMessageInfo(context, fingerprint)'));
    expect(body, contains('.put("id", fingerprint)'));
    expect(body, contains('.put("sender", sender.trim().take(100))'));
    expect(body, contains('.put("receivedAt", receivedAt)'));
    expect(body, contains('.put("excludedAt", System.currentTimeMillis())'));
    expect(body, contains('excludedMessageBucketPrefix + fingerprint.take(2)'));
    expect(body, contains('excludedMessageInfoBucketPrefix + fingerprint.take(2)'));
    expect(body, contains('.commit()'));
    expect(body, contains('excludedMessageCipherCache.remove('));
    expect(body, isNot(contains('queueName')));
    expect(body, isNot(contains('.put("body"')));
    expect(body, isNot(contains('onChanged')));
    expect(body, isNot(contains('acknowledgeCommitted')));
    expect(body, isNot(contains('completedTransferBucketPrefix')));
    expect(native, contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
  });
}

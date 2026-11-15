import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M953 / #662: only actual nonfinancial verification may be excluded.
void main() {
  test('M953 new English app login codes are excluded for unknown senders', () {
    for (final sms in const [
      'Your login code is 482193',
      'Your sign-in code is 493012',
      'Authentication code: 618200 for your new app',
      'Access code 508119 to finish sign in',
      'Authorization code 125642. Never disclose it',
    ]) {
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(sms), isTrue,
          reason: sms);
      final facts = WaffraBankSmsFactsParser.parse(sms);
      expect(facts.kind, WaffraBankOperationKind.uncertain, reason: sms);
      expect(facts.pending, isTrue, reason: sms);
      final result = WaffraSmsLocalRules.resolveSpecial(
          body: sms, sender: 'BrandNewApp', bankKind: facts.kind);
      expect(result?.resolvedKind, 'excluded', reason: sms);
      expect(result?.autoPost, isFalse);
      expect(result?.financial, isFalse);
    }
  });

  test('M953 new Arabic app codes are excluded for unknown senders', () {
    for (final sms in const [
      'رمز المصادقة الخاص بك هو 572399',
      'كود التحقق لتسجيل الدخول هو 529876',
      'كود الدخول هو 824551',
      'كود التفعيل للتطبيق الجديد 138114',
    ]) {
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(sms), isTrue,
          reason: sms);
      final facts = WaffraBankSmsFactsParser.parse(sms);
      expect(facts.kind, WaffraBankOperationKind.uncertain, reason: sms);
      final result = WaffraSmsLocalRules.resolveSpecial(
          body: sms, sender: 'AppArabic', bankKind: facts.kind);
      expect(result?.resolvedKind, 'excluded', reason: sms);
      expect(result?.autoPost, isFalse);
    }
  });

  test('M953 bank debit and transfer mixed with OTP are never excluded', () {
    for (final sms in const [
      'Card Purchase SAR 75.00 OTP verification code 562810',
      'تم شراء بمبلغ 120 ريال، كود التحقق 198100',
      'تم خصم 200 ريال من حسابك. رمز المصادقة 692883',
      'Transfer completed SAR 500. Your login code is 778811',
    ]) {
      expect(WaffraBankSmsFactsParser.isVerificationChallenge(sms), isTrue);
      final facts = WaffraBankSmsFactsParser.parse(sms);
      expect(facts.canAutoPostAsIncomeExpense, isFalse);
      final result = WaffraSmsLocalRules.resolveSpecial(
          body: sms, sender: 'Bank', bankKind: facts.kind);
      expect(result?.resolvedKind, isNot('excluded'), reason: sms);
    }
  });

  test('M953 confirmed purchase without OTP cannot match OTP fallback', () {
    const sms = 'Card Purchase SAR 150.00 at Market';
    expect(WaffraBankSmsFactsParser.isVerificationChallenge(sms), isFalse);
    final facts = WaffraBankSmsFactsParser.parse(sms);
    final special = WaffraSmsLocalRules.resolveSpecial(
        body: sms, sender: 'Bank', bankKind: facts.kind);
    expect(special?.id, isNot('builtin_verified_challenge'));
  });

  test('M953 background and foreground share exclusion decision and ACK', () {
    final foreground = File('lib/main.dart').readAsStringSync();
    final background =
        File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
    expect(foreground, contains('WaffraSmsLocalRules.resolveSpecial('));
    expect(foreground, contains("if(local['kind']=='excluded'){"));
    expect(background, contains('WaffraSmsLocalRules.resolveSpecial('));
    expect(background, contains('WaffraBankSmsFactsParser.isVerificationChallenge(body)'));
    expect(background, contains("rule?.resolvedKind=='excluded'"));
    expect(background, contains('verifiedChallenge||approvedCustom'));
    expect(background, contains('WaffraAutoSms.acknowledge([id])'));
  });

  test('M953 structural OTP rule has no finance posting authorization', () {
    const sms = 'Your login code is 991188';
    final facts = WaffraBankSmsFactsParser.parse(sms);
    final rule = WaffraSmsLocalRules.resolveSpecial(
        body: sms, sender: 'BrandNewApp', bankKind: facts.kind);
    expect(rule?.id, 'builtin_verified_challenge');
    expect(rule?.autoPost, isFalse);
    expect(rule?.accountId, isEmpty);
    expect(rule?.accountSuffix, isEmpty);
  });
}

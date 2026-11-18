import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M1037 #763: user owns the SMS text; storage encryption is not a UI label.
void main() {
 final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
 final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
 final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
 final page=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
 final rules=File('lib/waffra_home_sms_rules.part.dart').readAsStringSync();
 final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();

 test('owner exclusion stores reviewed (OTP-masked) body in encrypted label atomically',(){
  final section=native.substring(native.indexOf('fun excludeMessages(context: Context'),
   native.indexOf('fun acknowledgeCompletedTransfer(',native.indexOf('fun excludeMessages(context: Context')));
  expect(section,contains('.put("body", row.optString("body"))'));
  expect(section,contains('.put("sensitiveOtp", row.optBoolean("sensitiveOtp", false))'));
  expect(section,contains('.put("excludedAt", System.currentTimeMillis())'));
  expect(section,contains('seal(JSONArray(details.values.toList()).toString())'));
  expect(section,contains('.putString(queueName, seal(remaining.toString()))'));
  expect(section,contains('editor.commit()'));
  expect(section,isNot(contains('context.contentResolver.delete(')));
 });

 test('OTP automatic intake never stores original secret text in exclusion label',(){
  final start=native.indexOf('private fun recordPureOtpExclusionLocked(');
  final end=native.indexOf('private val debtNotice',start);
  final onlyOtp=native.substring(start,end);
  expect(onlyOtp,isNot(contains('.put("body"')));
  expect(native,contains('val masked = if (sensitive) redactMixedOtpSecrets(body)'));
 });

 test('one-message owner-only detail checks real fingerprint and respects legacy empty body',(){
  expect(native,contains('fun excludedMessageDetails(context: Context, id: String)'));
  expect(native,contains('isExcludedMessageLocked(context, id)'));
  expect(native,contains('fun findOriginalExcludedSms('));
  expect(native,contains('id(sender, body, identityAt) != fingerprint'));
  expect(native,contains('pureVerificationOnly(body)'));
  expect(native,contains('signedInOwnerHash(context)'));
  expect(activity,contains('"excludedAutoSmsMessageDetails" ->'));
  expect(bridge,contains('static Future<Map<String,Object?>?> excludedMessageDetails(String id)'));
  expect(bridge,contains("'excludedAutoSmsMessageDetails'"));
 });

 test('UI shows true sender/time/text and honest unavailable fallback, not fixed encrypted label',(){
  expect(page,contains('WaffraAutoSms.excludedMessageDetails(id)'));
  expect(page,contains('SelectableText('));
  expect(page,contains('receivedAt'));
  expect(page,contains('excludedAt'));
  expect(page,contains('نص الرسالة الأصلي'));
  expect(page,contains('تعذر استرجاع نص الرسالة'));
  expect(page,isNot(contains('رسالة مستبعدة منفردة (محفوظة مشفرة على الجهاز)')));
  expect(page,contains('القواعد المتعلّمة'));
  expect(page,contains('الرسائل المستبعدة فرديًا'));
 });

 test('safe denial explicitly identifies financial operation and unsupported template',(){
  const financial='شراء عبر نقاط البيع بطاقة: **6314 MADA مبلغ: 75 SAR لدى BK في 2026-11-07 16:06';
  expect(WaffraSmsLocalRules.exclusionLearningBlocker(
   body:financial,sender:'AlinmaPay'), 'financial_operation');
  expect(WaffraSmsLocalRules.suggestedGlobalRule(
   body:financial,sender:'AlinmaPay',kind:'excluded'),isNull);
  expect(WaffraSmsLocalRules.exclusionLearningBlocker(
   body:'مرحبًا في النظام',sender:'Bank-A'), 'unsupported_template');
  expect(WaffraSmsLocalRules.exclusionLearningBlocker(
   body:'رمز التحقق لتسجيل الدخول',sender:'Bank-A'),isNull);
 });

 test('learning communicates exact reason and verifies encrypted persistence',(){
  expect(rules,contains('void Function(String)? onFailure'));
  expect(rules,contains("onFailure?.call('owner_unavailable')"));
  expect(rules,contains('exclusionLearningBlocker('));
  expect(rules,contains("onFailure?.call('rule_storage_unavailable')"));
  expect(rules,contains('blockedConflicts'));
  expect(rules,contains('blockedCapacity'));
  expect(rules,contains('await store.read(_smsRuleOwnerKey)'));
  expect(review,contains('learningFailure'));
  expect(review,contains('waffraExclusionLearningReason('));
  expect(review,contains('لم يتم تعلّم قاعدة للرسائل المشابهة'));
 });

 test('never infer whole sender block or authorize financial posting',(){
  final start=native.indexOf('fun excludeMessages(context: Context');
  final end=native.indexOf('fun acknowledgeCompletedTransfer(',start);
  expect(native.substring(start,end),isNot(contains('excludeSender(')));
  expect(review,contains('WaffraAutoSms.excludeMessages([id])'));
  expect(rules,contains('Only a specific, independently classified message may produce a rule'));
  expect(native,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
 });
}

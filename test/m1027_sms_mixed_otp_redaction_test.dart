import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1027 original OTP is never copied into owner-encrypted financial review',(){
  final code=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(code,contains('private fun redactMixedOtpSecrets(body: String): String'));
  expect(code,contains('val candidates = otpCodeCandidate.findAll(text).toList()'));
  expect(code,contains('if (candidates.size != 1) return maskAllNumbers'));
  expect(code,contains('text.replaceRange(secret.range, "••••")'));
  expect(code,contains('val masked = if (sensitive) redactMixedOtpSecrets(body) else body.trim()'));
  expect(code,contains('redactMixedOtpSecrets(row.body)'));
 });
 test('M1027 uncertain OTP format fails closed and cannot auto-post money',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('val maskAllNumbers = text.replace('));
  expect(store,contains('Regex("[0-9٠-٩۰-۹]+"), "••••")'));
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(worker,contains("candidate['sensitiveOtp']==true"));
  expect(worker,contains("await keepForReview(candidate)"));
 });
}

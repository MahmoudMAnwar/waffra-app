import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('M429 integrates single SMS opt-in, phone login and OS biometrics',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains('autoSmsConsentPending?WaffraAutoSmsConsentPage'));
  expect(src,contains('locked?WaffraMandatoryBiometricGate'));
  expect(src,contains('WaffraLocalPhoneCredentials.verify('));
  expect(src,contains('WaffraLocalAccountMigration('));
  expect(src,contains('WaffraSmsCloudService.setConsent(enabled)'));
  expect(src,contains('await WaffraAutoSms.disable();'));
  expect(src,isNot(contains("_accountTile(waffraIsEnglish?'PIN app lock'")));
 });
 test('M429 Cloudflare is app-attested, free-only and never embeds staging key',(){
  final cloud=File('lib/waffra_sms_cloud_service.dart').readAsStringSync();
  final worker=File('cloudflare/waffra_sms_worker.mjs').readAsStringSync();
  expect(cloud,contains('waffra_cloud_sms_installation_consent_v2'));
  expect(cloud,contains('FirebaseAppCheck'));
  expect(worker,contains('SMS_RATE_LIMITER'));
  expect(worker,contains('SMS_IP_LIMITER'));
  expect(worker,contains("'openrouter/free'"));
  expect(worker,isNot(contains('WAFFRA_STAGING_TOKEN')));
 });
}

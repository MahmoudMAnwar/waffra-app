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
 test('M430: first-run consent does not reimport historical bank inbox',(){
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final consent=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  expect(bridge,isNot(contains("channel.invokeMethod<int>('importRecentBankSms')")));
  expect(consent,contains('final activated=await WaffraSmsCloudService.setConsent(cloud);'));
  expect(consent,contains('if(cloud&&!activated)'));
 });
 test('M432 signed QA APK Cloudflare staging is manual and main only',(){
  final workflow=File('.github/workflows/android.yml').readAsStringSync();
  expect(workflow,contains('sms_staging_worker:'));
  expect(workflow,contains('default: false'));
  expect(workflow,contains('github.event_name'));
  expect(workflow,contains('refs/heads/main'));
  expect(workflow,contains('Cloud SMS staging APK is allowed only from main'));
  expect(workflow,contains('WAFFRA_SMS_WORKER_URL=https://waffra-sms-appcheck-staging.mahmoudmanwar159.workers.dev/analyze'));
  expect(workflow,contains('"\${sms_define[@]}"'));
  expect(workflow,contains('flutter build appbundle --no-pub --release --target-platform android-arm64 --tree-shake-icons "\${eia_define[@]}"'));
  expect(workflow,isNot(contains('OPENROUTER_API_KEY')));
 });

}

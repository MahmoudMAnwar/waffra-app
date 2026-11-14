import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_cloud_redactor.dart';

void main() {
 test('M690 retired external SMS service fails closed before staging',(){
  final cloud=File('lib/waffra_sms_cloud_service.dart').readAsStringSync();
  expect(cloud,contains('hasConsent()async=>false'));
  expect(cloud,contains('analyzeIfConsented(String source)async=>null'));
  expect(cloud,isNot(contains('http.Client')));
 });

 test('M436 native queue claim is atomic and withholds future retries',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  final dart=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(store,contains('fun claimCloudAttempt('));
  expect(store,contains('synchronized(mutex)'));
  expect(store,contains('cloudAttemptAtMs'));
  expect(store,contains('86400000L'));
  expect(store,contains('if (row.has("cloud"))'));
  expect(activity,contains('"claimAutoBankSmsCloudAttempt"'));
  expect(worker,contains('"claimAutoBankSmsCloudAttempt"'));
  expect(dart,contains("_boolCall('claimAutoBankSmsCloudAttempt',id)"));
 });

 test('M452 background posts only with account-bound owner rule',(){
  final auto=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final main=readWaffraMainSourceForContracts();
  expect(auto,contains('!matched.autoPost'));
  expect(auto,contains('matched.accountSuffix'));
  expect(auto,contains('matched.accountId'));
  expect(auto,contains('sourceAccountVerified:true'));
  expect(auto,contains('WaffraProductionFinanceAuthorityBinding.bind('));
  expect(auto,contains('commitConfirmedSms('));
  expect(auto,isNot(contains('WaffraSmsCloudReviewAnalyzer.stagePending(')));
  // Owner retired the orphan per-message AI menu, not the protected cloud
  // service's redaction, permission and no-autopost safety contracts.
  expect(main,isNot(contains('Future<void> _analyzeAmbiguousSmsOnDemand(')));
  expect(main,isNot(contains('explicitlyRequested:true')));
  expect(main,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
  expect(main,contains('reviewSmsBudgetLinks([record])'));
 });

 test('M690 Android release has no Cloudflare staging configuration',(){
  final build=File('.github/workflows/android.yml').readAsStringSync();
  expect(build,isNot(contains('WAFFRA_SMS_WORKER_URL=')));
  expect(build,isNot(contains('sms_define')));
  expect(build,isNot(contains('sms_staging_worker:')));
 });

 test('M452 no unsolicited cloud choice on signup or SMS review',(){
  final ui=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  final main=readWaffraMainSourceForContracts();
  final cloud=File('lib/waffra_sms_cloud_service.dart').readAsStringSync();
  expect(ui,contains("await prefs.remove('waffra_cloud_sms_installation_consent_v2');"));
  expect(ui,isNot(contains('WaffraSmsCloudService')));
  expect(ui,contains('await WaffraAutoSms.optIn()'));
  expect(ui,isNot(contains('allow(cloud:true)')));
  expect(main,isNot(contains('Analyze this unclear message with AI?')));
  expect(main,isNot(contains('Send this message')));
  expect(main,isNot(contains('WaffraSmsCloudService.setConsent(true)')));
  expect(main,isNot(contains('Optional AI review')));
  expect(main,isNot(contains('ليست عملية مالية')));
  expect(cloud,contains('hasConsent()async=>false'));
  expect(cloud,contains('analyzeIfConsented(String source)async=>null'));
  expect(cloud,isNot(contains('FirebaseAppCheck')));
 });

 test('M436 redactor accepts compact English multi-currency SMS',(){
  final samples=[
   'JOD198.000 credited to account from CliQ transfer.',
   'JOD10.000 debited from account via CliQ transfer.',
   '136.00 AED debited for restaurant purchase.',
  ];
  for(final message in samples){
   expect(WaffraSmsCloudRedactor.redact(message),isNotNull,
    reason:'Missing safe money/action parsing for compact currency');
  }
  expect(WaffraSmsCloudRedactor.redact(
   'Your OTP verification code is 123456 for login'),isNull);
 });

}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M436 cloud suggestions are consented and budgeted, never posted',(){
  final src=File('lib/waffra_sms_cloud_review_analyzer.dart')
   .readAsStringSync();
  expect(src,contains('WaffraSmsCloudService.hasConsent()'));
  expect(src,contains('WaffraSmsCloudRedactor.redact(body)==null'));
  expect(src,contains('WaffraAutoSms.claimCloudAttempt(id)'));
  expect(src,contains('WaffraSmsCloudService.analyzeIfConsented(body)'));
  expect(src,contains('WaffraAutoSms.stageCloudAnalysis(id,safe)'));
  expect(src,contains("..['requiresReview']=true"));
  expect(src,contains('perInstallationDailyLimit=8'));
  expect(src,contains('await prefs.setInt(_usedKey,used)'));
  expect(src,isNot(contains('commitConfirmedSms(')));
  expect(src,isNot(contains('writeFinance(')));
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

 test('M436 background and foreground only stage review suggestions',(){
  final auto=File('lib/waffra_auto_sms_autopost.part.dart')
   .readAsStringSync();
  final main=File('lib/main.dart').readAsStringSync();
  expect(auto,contains('static bool get reviewOnly => true;'));
  final review=auto.substring(
   auto.indexOf('if(reviewOnly)'),
   auto.indexOf('final prefs=await SharedPreferences.getInstance();'));
  expect(review,contains('WaffraSmsCloudReviewAnalyzer.stagePending('));
  expect(review,contains('return summary;'));
  expect(review,isNot(contains('commitConfirmedSms(')));
  final home=main.substring(
   main.indexOf('Future<void> _refreshAutoSmsInbox('),
   main.indexOf('Future<void> _openAutoSmsInbox()'));
  expect(home,contains('WaffraSmsCloudReviewAnalyzer.stagePending('));
  expect(home,contains('_cloudReviewStageRunning'));
  expect(home,isNot(contains('commitConfirmedSms(')));
  expect(main,contains('اقتراح AI'));
  expect(main,contains('اقتراحات من الذكاء الاصطناعي'));
  expect(main,contains('await bulkSmsSheet(initialText:body)'));
  expect(main,contains('reviewSmsBudgetLinks(additions)'));
 });

 test('M436 signed main QA APK enables protected staging, not Play AAB',(){
  final build=File('.github/workflows/android.yml').readAsStringSync();
  final apk=build.substring(
   build.indexOf('      - name: Build optimized ARM64 Release APK'),
   build.indexOf('      - name: Measure release APK size'));
  final aab=build.substring(
   build.indexOf('      - name: Build Android App Bundle candidate for Google Play internal testing'),
   build.indexOf('      - name: Validate signed AAB archive'));
  expect(apk,contains('github.event_name'));
  expect(apk,contains('"push"'));
  expect(apk,contains('refs/heads/main'));
  expect(apk,contains('WAFFRA_SMS_WORKER_URL=https://waffra-sms-appcheck-staging.'));
  expect(apk,contains('"\${sms_define[@]}"'));
  expect(aab,isNot(contains('sms_define')));
  expect(build,isNot(contains('OPENROUTER_API_KEY')));
 });

 test('M436 separate cloud opt-in remains disclosed before upload',(){
  final ui=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  final cloud=File('lib/waffra_sms_cloud_service.dart').readAsStringSync();
  expect(ui,contains("allow(cloud:true)"));
  expect(ui,contains("allow(cloud:false)"));
  expect(ui,contains("if(cloud&&!activated)"));
  expect(ui,contains('تُحلّل الرسائل المؤهلة تلقائيًا'));
  expect(ui,contains('بعد حجب البيانات'));
  expect(cloud,contains('FirebaseAppCheck.instance.getToken()'));
  expect(cloud,contains('WaffraCloudflareSmsGateway.analyze('));
  expect(cloud,contains('WaffraSmsCloudRedactor.redact(source)'));
 });
}

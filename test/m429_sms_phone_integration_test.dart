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
  expect(consent,contains('await WaffraSmsCloudService.setConsent(false)'));
  expect(consent,contains('await WaffraAutoSms.optIn()'));
 });

 test('M433 month-bounded encrypted SMS import is manual-review only',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final poster=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(store,contains('fun importConsentMonth('));
  expect(store,contains('Calendar.DAY_OF_MONTH, 1'));
  expect(store,contains('"date >= ? AND date < ?"'));
  expect(store,contains('history_cursor_at'));
  expect(store,contains('historical = true'));
  expect(store,contains('maxCandidates = 100'));
  expect(activity,contains('"importConsentMonthBankSms"'));
  expect(bridge,contains("channel.invokeMethod<int>('importConsentMonthBankSms')"));
  expect(poster,contains('static bool get reviewOnly => false;'));
  expect(poster,contains('!matched.autoPost'));
  expect(poster,contains('matched.accountSuffix'));
  expect(poster,contains('commitConfirmedSms('));
  expect(poster,isNot(contains('WaffraSmsCloudReviewAnalyzer.stagePending(')));
 });
 test('M433 Home has stable review inbox count and per-SMS manual review',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains("Key('waffra-auto-sms-review-card')"));
  expect(main,contains("Key('waffra-auto-sms-review-count')"));
  expect(main,contains("Key('waffra-auto-sms-review-open')"));
  expect(main,contains('await WaffraAutoSms.importConsentMonth()'));
  expect(main,contains('Future<void> _openAutoSmsInbox()'));
  expect(main,contains('bulkSmsSheet(initialText:body,'));
  expect(main,contains('reviewSmsBudgetLinks(additions)'));
  expect(main,contains('if(targetId!=null&&id!=targetId)continue;'));
 });
  test('M436 signed QA APK Cloudflare staging is main only, cloud opt-in',(){
  final workflow=File('.github/workflows/android.yml').readAsStringSync();
  expect(workflow,contains('sms_staging_worker:'));
  expect(workflow,contains('default: false'));
  expect(workflow,contains('github.event_name'));
  expect(workflow,contains('"push"'));
  expect(workflow,contains('refs/heads/main'));
  expect(workflow,contains('Cloud SMS staging APK is allowed only from main'));
  expect(workflow,contains('WAFFRA_SMS_WORKER_URL=https://waffra-sms-appcheck-staging.mahmoudmanwar159.workers.dev/analyze'));
  expect(workflow,contains('"\${sms_define[@]}"'));
  expect(workflow,contains('flutter build appbundle --no-pub --release --target-platform android-arm64 --tree-shake-icons "\${eia_define[@]}"'));
  expect(workflow,isNot(contains('OPENROUTER_API_KEY')));
 });


 test('M434 encrypted SMS inbox groups real sender and displays count',(){
  final main=File('lib/main.dart').readAsStringSync();
  final inbox=main.substring(
   main.indexOf('Future<void> _openAutoSmsInbox()async{'),
   main.indexOf('Widget _autoSmsReviewCard(){'));
  expect(inbox,contains("final bySender=<String,List<Map<String,Object?>>>{};"));
  expect(inbox,contains("candidate['sender']"));
  expect(inbox,contains('bySender.putIfAbsent('));
  expect(inbox,contains("'waffra-sms-sender-list'"));
  expect(inbox,contains("'waffra-sms-sender-transactions'"));
  expect(inbox,contains("Key('waffra-sms-sender-group-'"));
  expect(inbox,contains("Key('waffra-sms-sender-message-'"));
  expect(inbox,contains('await _reviewAutoSmsCandidates(targetId:selected)'));
  expect(inbox,isNot(contains('commitConfirmedSms(')));
 });
 test('M434 saved transactions preserve genuine SMS versus manual origin',(){
  final main=File('lib/main.dart').readAsStringSync();
  final details=main.substring(
   main.indexOf('class WaffraTransactionDetailsDialog'),
   main.indexOf('class HomeScreen extends StatefulWidget'));
  expect(details,contains("'sms'=>english?'Bank SMS':'رسالة بنكية (SMS)'"));
  expect(details,contains("'manual'=>english?'Manual entry':'إدخال يدوي'"));
  expect(details,contains('معاملة سابقة (المصدر غير محدد)'));
  expect(details,contains("Key('waffra-transaction-source-provenance')"));
  expect(details,contains("entry.sourceType=='manual'"));
  expect(details,contains("entry.sourceType=='sms'"));
  expect(main,contains('WaffraTransactionDetailsDialog.sourceLabel('));
  expect(main,contains('protectedOriginalSms:originalBankSms'));
  expect(main,contains("Key('waffra-entry-edit-source')"));
 });


 test('M443 merchant and logo UI removed without deleting finance history',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,isNot(contains("import 'waffra_merchant_brands.dart';")));
  expect(main,isNot(contains('WaffraMerchantLogo(')));
  expect(main,isNot(contains('WaffraMerchantBrands.match(')));
  expect(main,isNot(contains('waffraChooseMerchantBrand(')));
  expect(main,isNot(contains("Key('waffra-transaction-select-merchant')")));
  expect(main,isNot(contains('selectedMerchantOverride')));
  // Original merchantKey metadata remains unchanged for historical finance
  // transactions and cross-source duplicate detection.
  expect(main,contains('merchantKey:initial?.merchantKey??'));
  expect(main,contains('candidateMerchantKey:result.merchantKey'));
  expect(main,contains('existingMerchantKey:e.merchantKey'));
 });

}

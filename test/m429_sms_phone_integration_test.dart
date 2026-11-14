import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('M429 integrates single SMS opt-in, phone login and OS biometrics',(){
  final src=readWaffraMainSourceForContracts();
  expect(src,contains('final laterConsent=!needsLogin&&!firstConsent&&!needsGate&&autoSmsConsentPending;'));
  expect(src,contains('child:WaffraMandatoryBiometricGate'));
  expect(src,contains('WaffraLocalPhoneCredentials.verify('));
  expect(src,contains('WaffraLocalAccountMigration('));
  expect(src,isNot(contains('WaffraSmsCloudService.setConsent(enabled)')));
  expect(src,contains('await WaffraAutoSms.disable();'));
  expect(src,isNot(contains("_accountTile(waffraIsEnglish?'PIN app lock'")));
 });
 test('M690 retired cloud SMS service cannot enable or upload',(){
  final cloud=File('lib/waffra_sms_cloud_service.dart').readAsStringSync();
  expect(cloud,contains('hasConsent()async=>false'));
  expect(cloud,contains('await prefs.remove(_key)'));
  expect(cloud,contains('analyzeIfConsented(String source)async=>null'));
  expect(cloud,isNot(contains('FirebaseAppCheck')));
 });
 test('M430: first-run consent does not reimport historical bank inbox',(){
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final consent=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  expect(bridge,isNot(contains("channel.invokeMethod<int>('importRecentBankSms')")));
  expect(consent,contains("await prefs.remove('waffra_cloud_sms_installation_consent_v2');"));
  expect(consent,isNot(contains('waffra_sms_cloud_service.dart')));
  expect(consent,contains('await WaffraAutoSms.optIn()'));
 });

 test('M433 month-bounded encrypted SMS import is manual-review only',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  final poster=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(store,contains('fun importConsentMonth('));
  expect(store,contains('Calendar.DAY_OF_MONTH, 1'));
  expect(store,contains('(date > ? OR (date = ? AND _id > ?)) AND date < ?'));
  expect(store,contains('history_cursor_at'));
  expect(store,contains('.put("reviewNotified", true)'));
  expect(store,contains('maxCandidates = 1000'));
  expect(activity,contains('"importConsentMonthBankSms"'));
  expect(bridge,contains("channel.invokeMethod<int>('importConsentMonthBankSms')"));
  expect(poster,contains('static bool get reviewOnly => false;'));
  expect(poster,contains('!matched.autoPost'));
  expect(poster,contains('matched.accountSuffix'));
  expect(poster,contains('commitConfirmedSms('));
  expect(poster,isNot(contains('WaffraSmsCloudReviewAnalyzer.stagePending(')));
 });
 test('M433 Home has stable review inbox count and per-SMS manual review',(){
  final main=readWaffraMainSourceForContracts();
  expect(main,contains("Key('waffra-auto-sms-review-card')"));
  expect(main,contains("Key('waffra-auto-sms-review-count')"));
  expect(main,contains("Key('waffra-auto-sms-review-open')"));
  expect(main,contains('await WaffraAutoSms.importConsentMonth()'));
  expect(main,contains('Future<void> _openAutoSmsInbox()'));
  expect(main,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
  expect(main,contains('reviewSmsBudgetLinks([record])'));
  expect(main,contains('if(targetId!=null&&id!=targetId)continue;'));
 });
 test('M690 no signed APK or AAB contains cloud SMS staging',(){
  final build=File('.github/workflows/android.yml').readAsStringSync();
  expect(build,isNot(contains('WAFFRA_SMS_WORKER_URL=')));
  expect(build,isNot(contains('sms_staging_worker:')));
  expect(build,isNot(contains('sms_define')));
  expect(build,contains('flutter build appbundle --no-pub --release'));
 });

 test('M434 encrypted SMS inbox groups real sender and displays count',(){
  final main=readWaffraMainSourceForContracts();
  final inbox=main.substring(
   main.indexOf('Future<void> _openAutoSmsInbox()async{'),
   main.indexOf('Widget _autoSmsReviewCard(){'));
  // The presentation-only grouping moved into a pure O(N) helper. Do not
  // regress original sender identity, case-insensitive grouping or UI routes.
  final groups=File('lib/waffra_sms_review_groups.dart').readAsStringSync();
  expect(inbox,contains('WaffraSmsReviewGroups.from(_autoSmsPending'));
  expect(inbox,contains('final bySender=grouped.bySender;'));
  expect(inbox,contains('final senders=grouped.senders;'));
  expect(groups,contains("message['sender']"));
  expect(groups,contains('canonicalNames.putIfAbsent('));
  expect(groups,contains('bySender.putIfAbsent('));
  expect(groups,contains('rows.sort('));
  expect(inbox,contains("'waffra-sms-sender-list'"));
  expect(inbox,contains("'waffra-sms-sender-transactions'"));
  expect(inbox,contains("Key('waffra-sms-sender-group-'"));
  expect(inbox,contains("Key('waffra-sms-sender-message-'"));
  // #410: the sender route stays mounted while the message is reviewed.
  expect(inbox,contains('await showModalBottomSheet<void>('));
  expect(inbox,contains('await _reviewAutoSmsCandidates(targetId:id);'));
  expect(inbox,contains('openingReviewId=null;'));
  expect(inbox,isNot(contains('commitConfirmedSms(')));
 });
 test('M434 saved transactions preserve genuine SMS versus manual origin',(){
  final main=readWaffraMainSourceForContracts();
  final details=main.substring(
   main.indexOf('class WaffraTransactionDetailsDialog'),
   main.indexOf('class HomeScreen extends StatefulWidget'));
  // #404: provenance still identifies SMS, now explicitly human-reviewed.
  expect(details,contains("'sms'=>english?'Bank SMS — reviewed and saved manually':"));
  expect(details,contains('رسالة بنكية (SMS) — تمت مراجعتها وتسجيلها يدويًا'));
  expect(details,isNot(contains("'sms'=>english?'Manual entry'")));
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
  final main=readWaffraMainSourceForContracts();
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

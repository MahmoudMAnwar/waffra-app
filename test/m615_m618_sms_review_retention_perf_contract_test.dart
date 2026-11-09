import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M615 approved review is structured and scroll thumb stays off RTL SMS',(){
  final main=File('lib/main.dart').readAsStringSync();
  final section=main.substring(
   main.indexOf(' Future<void> _reviewAutoSmsCandidates('),
   main.indexOf(' void _receiveSharedSms(){'));
  expect(main,contains('Widget _m615ReviewDetail('));
  expect(section,contains('Scrollbar(controller:reviewScroll,thumbVisibility:true,'));
  expect(section,contains('EdgeInsetsDirectional.only(start:6,end:24)'));
  expect(section,contains("Key('waffra-sms-original-expand')"));
  expect(section,contains('initiallyExpanded:true'));
  expect(section,contains('SelectableText(body,textAlign:TextAlign.start)'));
  expect(section,contains('Card(color:Theme.of(dialog).colorScheme.surfaceContainerLow,'));
  expect(section,contains("Key('m565-sms-yes-confirm')"));
  expect(section,contains("Key('m565-sms-no-edit')"));
  expect(section,contains("Key('m595-review-single-exclude')"));
  expect(section.indexOf("Key('m595-review-single-exclude')"),
    greaterThan(section.indexOf("Key('m565-sms-no-edit')")));
  expect(section,isNot(contains('وفرة يتعلم القواعد الآمنة')));
  expect(section,isNot(contains('Safe rules update after confirmed actions.')));
 });

 test('M618 No/Edit alternatives are source-correct and must not auto-post',(){
  final main=File('lib/main.dart').readAsStringSync();
  final s=main.substring(main.indexOf(' Future<void> _reviewAutoSmsCandidates('),
   main.indexOf(' void _receiveSharedSms(){'));
  expect(s,contains("if(decision=='no'&&understood&&!sensitive&&"));
  expect(s,contains("const <String>['income','transfer']"));
  expect(s,contains("const <String>['expense','transfer']"));
  expect(s,contains("Key('m618-correct-to-'+kind)"));
  expect(s,contains("decision='correct-type'"));
  expect(s,contains("if(reviewType=='transfer'){"));
  expect(s,contains('await openVerifiedTransfer();'));
  expect(s,contains("reviewedIncomeOverride:reviewType=='income'"));
  expect(s,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(s,contains("await WaffraAutoSms.excludeMessages([id])"));
  expect(s,contains('الرسالة بقت في قائمة المستبعدة لمدة 30 يوم'));
 });

 test('M616 30d reversible encrypted labels are distinct from immutable rescan denial',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(native,contains('excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000'));
  expect(native,contains('.put("excludedAt", System.currentTimeMillis())'));
  expect(native,contains('private fun pruneExcludedLabelsLocked('));
  expect(native,contains('pruneExcludedLabelsLocked(context, force = false)'));
  expect(native,contains('pruneExcludedLabelsLocked(context, force = true)'));
  expect(native,contains('now - excludedAt < excludedLabelRetentionMs'));
  expect(native,contains('if (changed && active.isEmpty()) editor.remove(key)'));
  expect(native,contains('val info = labels[id] ?: continue'));
  expect(native,contains('result.add(mapOf('));
  expect(native,contains('"excludedAt" to info.optLong('));
  // Revocable UI metadata may expire, but dedup fingerprints must never be
  // purged at the same time or old messages will reappear on Android rescan.
  final cleanup=native.substring(
   native.indexOf('private fun pruneExcludedLabelsLocked('),
   native.indexOf('/** Shows only excluded SMS identities'));
  expect(cleanup,isNot(contains('editor.remove(excludedMessageBucketPrefix')));
  expect(cleanup,isNot(contains('editor.remove(committedBucketPrefix')));
  expect(cleanup,isNot(contains('editor.remove(queueName')));
 });

 test('M618 notifications retain hidden sender selection and only block opt-in senders',(){
  final src=File('lib/waffra_approved_notifications.dart').readAsStringSync();
  final filter=src.substring(src.indexOf('Widget category('),
   src.indexOf('Widget noticeTile('));
  expect(filter,contains('filter=key;'));
  expect(filter,isNot(contains('selectedIds.clear();')));
  expect(src,contains('selectedIds.intersection(items.map((n)=>n.id).toSet())'));
  expect(src,contains('items.where((n)=>liveSelected.contains(n.id))'));
  expect(src,contains("blockSenders?senders:const []"));
  expect(src,contains("'الرسائل والمرسلين'"));
  expect(src,contains("'الرسائل فقط'"));
 });

 test('M617 verified login removes only the second OS probe and never skips secure KDF',(){
  final app=File('lib/main.dart').readAsStringSync();
  final signIn=app.substring(app.indexOf(' Future<void> _signIn()async{'),
   app.indexOf(' String get maskedLastPhone{'));
  expect(signIn,contains('await WaffraLocalPhoneCredentials.verify('));
  expect(signIn,contains('if(!match){'));
  expect(signIn,contains('await widget.onVerifiedPasswordSave(verifiedAccount);'));
  final saved=app.substring(app.indexOf(' Future<void> saveUser(Person u)async {'),
   app.indexOf(' Future<void> setUiCountry('));
  expect(saved,contains('!identical(_verifiedPhoneLoginProof,u)'));
  expect(saved,contains('WaffraLocalPhoneCredentials.probeForPhone(phone)'));
  expect(saved,contains('await _accountWriteAuthority.saveProfile('));
  expect(app,contains('onVerifiedPasswordSave:_saveVerifiedPhoneLogin'));
  expect(app,contains('try{await saveUser(u);}'));
  expect(app,isNot(contains("'بنفتح الرئيسية…'")));
  expect(app,contains('child:!ready&&_financeLoadFailure==null?'));
  expect(app,isNot(contains("'جارٍ تجهيز بياناتك المالية بأمان…'")));
 });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_cloudflare_sms_gateway.dart';
import 'package:waffra/waffra_sms_cloud_service.dart';

void main(){
 test('M690 old cloud consent cannot reenable remote analysis',()async{
  expect(await WaffraSmsCloudService.hasConsent(),isFalse);
  expect(await WaffraSmsCloudService.setConsent(true),isFalse);
  expect(await WaffraSmsCloudService.analyzeIfConsented(
   'تم شراء بقيمة 12.00 ريال من الحساب'),isNull);
 });
 test('M690 local SMS expense, salary and OTP behavior remains intact',(){
  expect(WaffraBankSmsFactsParser.parse('شراء بقيمة 12 ريال').kind,
   WaffraBankOperationKind.expense);
  expect(WaffraBankSmsFactsParser.parse('راتب 5000 ريال').kind,
   WaffraBankOperationKind.income);
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(
   'Your OTP verification code is 123456'),isTrue);
 });
 test('M698 no configured cloud gateway or old SMS cloud staging',(){
  expect(WaffraCloudflareSmsGateway.configured,isFalse);
  expect(WaffraCloudflareSmsGateway.configuredUrl,isEmpty);
  expect(File('lib/waffra_sms_cloud_review_analyzer.dart').existsSync(),isFalse);
 });
 test('M699 legacy cloud suggestions do not return in the SMS inbox',(){
  final inbox=File('lib/main.dart').readAsStringSync();
  expect(inbox,isNot(contains('AI suggestion •')));
  expect(inbox,isNot(contains('اقتراح AI •')));
  expect(inbox,isNot(contains('cloud AI suggestions ready')));
  expect(inbox,contains('final ambiguous=count-localCount;'));
  expect(inbox,contains("((item['body'] as String?)??'')"));
 });
 test('M690 build and Settings never activate a cloud bank SMS model',(){
  final build=File('.github/workflows/android.yml').readAsStringSync();
  final profile=File('lib/waffra_home_profile.part.dart').readAsStringSync();
  expect(build,isNot(contains('WAFFRA_SMS_WORKER_URL=')));
  expect(build,isNot(contains('sms_staging_worker:')));
  expect(profile,isNot(contains('AI analysis of bank SMS (cloud)')));
  expect(profile,isNot(contains('OpenRouter')));
 });
}

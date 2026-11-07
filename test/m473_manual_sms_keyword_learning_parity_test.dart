import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M473 #413: confirmed manual description teaches review-only SMS category',(){
  final rule=WaffraSmsLocalRules.manualCategoryPattern(
   description:'شحن الجوال',category:'فواتير / جوال',income:false);
  expect(rule,isNotNull);
  expect(rule!.autoPost,isFalse);
  expect(rule.sender,isEmpty);
  expect(rule.accountId,isEmpty);
  expect(rule.accountSuffix,isEmpty);
  expect(rule.keywords,contains('الجوال'));
  // The later SMS has another word between the merchant/service hint.
  expect(WaffraSmsLocalRules.matches(rule,'تم شحن رصيد الجوال من البطاقة',
   sender:'AlinmaPay'),isTrue);
  final match=WaffraSmsLocalRules.resolve(
   body:'تم شحن رصيد الجوال من البطاقة',sender:'AlinmaPay',
   bankKind:WaffraBankOperationKind.expense,custom:[rule]);
  expect(match?.category,'فواتير / جوال');
  expect(match?.autoPost,isFalse);
  expect(WaffraSmsLocalRules.resolve(
   body:'تم شحن رصيد الجوال من البطاقة',sender:'AlinmaPay',
   bankKind:WaffraBankOperationKind.income,custom:[rule]),isNull);
 });

 test('M473 #413: learned expenses share one bucket without overriding categories',(){
  final mobile=WaffraSmsLocalRules.manualCategoryPattern(
   description:'شحن الجوال',category:'فواتير / جوال',income:false)!;
  final streaming=WaffraSmsLocalRules.manualCategoryPattern(
   description:'اشتراك نتفليكس',category:'اشتراكات / ترفيه',income:false)!;
  final first=WaffraSmsLocalRules.upsertLearned(
   existing:const <WaffraSmsLocalRule>[],candidate:mobile);
  final both=WaffraSmsLocalRules.upsertLearned(
   existing:first,candidate:streaming);
  expect(both.length,1);
  expect(both.single.autoPost,isFalse);
  expect(both.single.keywordCategories.isNotEmpty,isTrue);
  expect(WaffraSmsLocalRules.resolve(
   body:'دفع اشتراك نتفليكس من محفظتي',sender:'AlinmaPay',
   bankKind:WaffraBankOperationKind.expense,custom:both)?.category,
   'اشتراكات / ترفيه');
  expect(WaffraSmsLocalRules.resolve(
   body:'تم شحن رصيد الجوال',sender:'AlinmaPay',
   bankKind:WaffraBankOperationKind.expense,custom:both)?.category,
   'فواتير / جوال');
  final duplicate=WaffraSmsLocalRules.upsertLearned(
   existing:both,candidate:streaming);
  expect(duplicate.length,both.length);
  expect(duplicate.single.keywords.length,both.single.keywords.length);
  final conflicted=WaffraSmsLocalRules.manualCategoryPattern(
   description:'شحن الجوال',category:'أخرى / خدمات',income:false)!;
  final rejected=WaffraSmsLocalRules.upsertLearned(
   existing:both,candidate:conflicted);
  expect(identical(rejected,both),isTrue);
 });

 test('M473 #413: preserve independent income directions and safe words',(){
  final salary=WaffraSmsLocalRules.manualCategoryPattern(
   description:'راتب الشركة',category:'وظيفة / راتب',income:true);
  expect(salary,isNotNull);
  expect(salary!.resolvedKind,'income');
  expect(salary.sender,isEmpty);
  expect(salary.autoPost,isFalse);
  final bad=WaffraSmsLocalRules.safeDescriptionKeywords(
   'بيانات IBAN ورمز التحقق');
  expect(bad,isEmpty);
  final noAccountLeak=WaffraSmsLocalRules.safeDescriptionKeywords(
   'شحن 8308 الجوال');
  expect(noAccountLeak.any((s)=>s.contains('8308')),isFalse);
  expect(WaffraSmsLocalRules.manualCategoryPattern(
   description:'دفع',category:'فواتير / جوال',income:false),isNull);
 });

 test('M473 #413: caller runs keyword learning only after verified writes',(){
  final main=File('lib/main.dart').readAsStringSync();
  final learning=main.substring(
   main.indexOf(' Future<void> _learnManualCategoryPreference('),
   main.indexOf(' Map<String,Object?>? _localSmsClassification('));
  expect(learning,contains("(record.sourceType!='manual'&&record.sourceType!='sms')"));
  expect(learning,contains('WaffraSmsLocalRules.manualCategoryPattern('));
  expect(learning,contains('WaffraSmsLocalRuleStore()'));
  final editor=main.substring(main.indexOf(' Future<void> entrySheet('),
   main.indexOf(' Future<void> showReceipt('));
  // The SMS branch precedes the manual branch in the same editor.
  // Each learning call must follow its OWN verified finance commit.
  final smsCommit=editor.indexOf('_financeAuthority.commitConfirmedSms(');
  final smsLearn=editor.indexOf(
    'try{await _learnManualCategoryPreference(result);}',smsCommit);
  final manualCommit=editor.indexOf('commitConfirmedManual(');
  final manualLearn=editor.indexOf(
    'try{await _learnManualCategoryPreference(result);}',manualCommit);
  expect(smsCommit,greaterThanOrEqualTo(0));
  expect(smsLearn,greaterThan(smsCommit));
  expect(manualCommit,greaterThan(smsLearn));
  expect(manualLearn,greaterThan(manualCommit));
  final sms=main.substring(main.indexOf(' Future<void> bulkSmsSheet('),
   main.indexOf(' Future<void> entrySheet('));
  expect(sms,contains('final descriptionRule=WaffraSmsLocalRules.manualCategoryPattern('));
  expect(sms,contains('try{await _learnManualCategoryPreference(entry);}'));
  expect(sms.indexOf('final descriptionRule=WaffraSmsLocalRules.manualCategoryPattern('),
   greaterThan(sms.indexOf('final persistedRaw=await WaffraLargeJsonDecode.parse(')));
  expect(sms,contains('if(!identical(originalRules,revisedRules))'));
 });
}

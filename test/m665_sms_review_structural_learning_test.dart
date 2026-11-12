import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main() {
 group('M665 / M660 safe, sender-scoped SMS template learning', () {
  test('one approved OTP covers other verification wording, not financial debit', () {
   const first='رمز التفعيل الخاص بك هو 482913، لا تشارك الرمز';
   const next='رمز التحقق الخاص بك هو 889100، لا تشارك الرمز';
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:first,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
   expect(rule,isNotNull);
   expect(rule!.templateFamily,'verification');
   expect(rule.matchAll,isTrue);
   expect(rule.autoPost,isFalse);
   expect(rule.toJson().toString(),isNot(contains('482913')));
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'AlRajhiBank'),isTrue);
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'UnrelatedBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم خصم 300 ريال. رمز التحقق 889100',
    sender:'AlRajhiBank'),isFalse);
   final restored=WaffraSmsLocalRule.fromJson(
    Map<String,dynamic>.from(rule.toJson()));
   WaffraSmsLocalRules.validate(restored);
   expect(restored.templateFamily,rule.templateFamily);
  });

  test('approved beneficiary management survives name and verb replacement', () {
   const source='تمت إضافة المستفيد: محمد صابر خليل محمد';
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:source,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
   expect(rule,isNotNull);
   expect(rule!.templateFamily,'beneficiary_management');
   expect(rule.toJson().toString(),isNot(contains('محمد صابر')));
   const next='تم تنشيط المستفيد: أحمد علي';
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'AlRajhiBank'),isTrue);
   expect(WaffraSmsLocalRules.matches(rule,next,sender:'OtherBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم خصم 50 ريال، تمت إضافة المستفيد: أحمد علي',
    sender:'AlRajhiBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم تحويل 100 ريال إلى المستفيد أحمد',
    sender:'AlRajhiBank'),isFalse);
   expect(WaffraSmsLocalRules.matches(rule,
    'تم تحويل 100 ريال. تم تنشيط المستفيد: أحمد',
    sender:'AlRajhiBank'),isFalse,
    reason:'A completed transfer event must defeat an exclusion template');
   final facts=WaffraBankSmsFactsParser.parse(next);
   expect(facts.kind,WaffraBankOperationKind.uncertain);
   final resolved=WaffraSmsLocalRules.resolveSpecial(
    body:next,sender:'AlRajhiBank',bankKind:facts.kind,custom:[rule]);
   expect(resolved?.id,rule.id);
  });

  test('one approved template is stable and never enables finance auto-post', () {
   final rule=WaffraSmsLocalRules.suggestedRule(
    body:'تمت إضافة المستفيد: محمد',sender:'AlRajhiBank',
    kind:'excluded',confidentOnly:true)!;
   final saved=WaffraSmsLocalRules.upsertLearned(
    existing:const <WaffraSmsLocalRule>[],candidate:rule);
   final again=WaffraSmsLocalRules.upsertLearned(
    existing:saved,candidate:rule);
   expect(saved,hasLength(1));
   expect(again,hasLength(1));
   expect(again.single.autoPost,isFalse);
   expect(again.single.sender,'AlRajhiBank');
   expect(again.single.contextFragments,everyElement(isNot(contains('محمد'))));
  });

  test('reviewed income and transfer hints stay separate from posting authority', () {
   final income=WaffraSmsLocalRules.suggestedRule(
    body:'Refund Received\nAmount: SAR 50.00',
    sender:'AlRajhiBank',kind:'income',
    category:'مبالغ مستردة / استرجاع مشتريات',confidentOnly:true);
   final transfer=WaffraSmsLocalRules.suggestedRule(
    body:'Credit Transfer via Alinma Bank\nAmount: SAR 1900.00',
    sender:'AlinmaBank',kind:'transfer');
   expect(income,isNotNull);
   expect(transfer,isNotNull);
   expect(income!.autoPost,isFalse);
   expect(transfer!.autoPost,isFalse);
   expect(income.matchAll,isTrue);
   expect(transfer.matchAll,isTrue);
   expect(transfer.financial,isFalse);
  });
 });

 group('M665 visual and event lifecycle source guards', () {
  test('compact review retains main and child correction on current sheet', () {
   final main=File('lib/main.dart').readAsStringSync();
   final start=main.indexOf(' Future<void> _reviewAutoSmsCandidates(');
   final end=main.indexOf(' void _receiveSharedSms(',start);
   final review=main.substring(start,end);
   expect(review,contains("Key('m665-review-pick-category')"));
   expect(review,contains('reviewedCategory=chosen.name;'));
   expect(review,contains('reviewedAccount=(ids:<String?>[pickedId],'));
   expect(review,contains('generation:fresh.witness.generation);'));
   expect(review,contains('reviewCategoryValid'));
   expect(review,contains('category:reviewedCategory,income:expectedIncome,'));
   expect(review,contains(
    'if(!sensitive&&!understood&&\n          facts.kind!=WaffraBankOperationKind.transfer)Padding('));
   expect(review,isNot(contains('راجع البيانات الناقصة من شاشة التعديل')));
   expect(main,contains("Key('waffra-entry-original-sms-expand')"));
  });

  test('notification rescan moved to pull; bulk select stays sender-sticky', () {
   final ui=File('lib/waffra_approved_notifications.dart').readAsStringSync();
   expect(ui,contains("Key('m665-notification-pull-refresh')"));
   expect(ui,contains('RefreshIndicator('));
   expect(ui,contains('AlwaysScrollableScrollPhysics()'));
   expect(ui,isNot(contains('Icons.refresh_rounded')));
   expect(ui,contains('Icons.check_box_outline_blank_rounded'));
   expect(ui,contains('Icons.check_box_rounded'));
   expect(ui,contains('filter=key;'));
   expect(ui,contains('selectedIds.add(item.id)'));
  });

  test('after secure rule write, classify queue without rescanning phone history', () {
   final main=File('lib/main.dart').readAsStringSync();
   final start=main.indexOf(' Future<bool> _learnSafeSmsRule({');
   final end=main.indexOf(' Future<void> _learnManualTransferPreference()',start);
   final fragment=main.substring(start,end);
   expect(fragment,contains('await store.write(_smsRuleOwnerKey,updated);'));
   expect(fragment,contains('_receiveAutoSmsNotice();'));
   expect(fragment,isNot(contains('importConsentMonthChecked()')));
   expect(main,contains('await compute(waffraM632ClassifySmsQueue'));
   expect(main,contains("local['kind']=='excluded'&&local['defaultSeed']!=true"));
  });
 });
}

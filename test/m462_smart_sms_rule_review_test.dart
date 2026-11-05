import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M462 verified income SMS builds a sender-scoped safe rule, never autoposts',(){
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',sender:'AlRajhiBank',
   kind:'income',category:'مبالغ مستردة / استرجاع مشتريات',
   confidentOnly:true);
  expect(rule,isNotNull);
  expect(rule!.income,isTrue);
  expect(rule.autoPost,isFalse);
  expect(rule.sender,'AlRajhiBank');
  expect(rule.category,'مبالغ مستردة / استرجاع مشتريات');
  expect(rule.keywords,contains('refund'));
  expect(rule.keywords.join(' '),isNot(contains('50.00')));
  expect(WaffraSmsLocalRules.matches(rule,
   'Refund Received\nAmount: SAR 50.00',sender:'AlRajhiBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(rule,
   'Refund Received\nAmount: SAR 50.00',sender:'OtherBank'),isFalse);
 });

 test('M462 generic or pending bank SMS cannot be learned confidently',(){
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase SAR 75.00 TEST FUEL STATION',
   sender:'Bank',kind:'expense',category:'أخرى / مصروف غير مصنف'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase declined SAR 42.50',
   sender:'Bank',kind:'expense',category:'السيارة / بنزين ووقود'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',
   sender:'',kind:'income',category:'مبالغ مستردة / استرجاع مشتريات'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',
   sender:'Bank',kind:'expense',category:'مبالغ مستردة / استرجاع مشتريات'),isNull);
 });

 test('M462 safe OTP exclusion records words and sender but never OTP value',(){
  const body='رمز التفعيل الخاص بك هو 482913، لا تشارك الرمز';
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:body,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
  expect(rule,isNotNull);
  expect(rule!.resolvedKind,'excluded');
  expect(rule.autoPost,isFalse);
  expect(rule.keywords,contains('رمز التفعيل'));
  expect(rule.toJson().toString(),isNot(contains('482913')));
  expect(WaffraSmsLocalRules.matches(rule,body,sender:'AlRajhiBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(rule,body,sender:'Unrelated'),isFalse);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase SAR 75.00 رمز التفعيل',
   sender:'AlRajhiBank',kind:'excluded'),isNull);
 });

 test('M462 transfer rules never create an expense',(){
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:'Credit Transfer via Alinma Bank\nAmount: SAR 1900.00',
   sender:'AlinmaBank',kind:'transfer');
  expect(rule,isNotNull);
  expect(rule!.financial,isFalse);
  expect(rule.autoPost,isFalse);
  expect(rule.keywords,isNotEmpty);
 });

 test('M462 beginner review is prefilled and keeps finance approval separate',(){
  final ui=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(ui,contains('seedCategory'));
  expect(ui,contains('proposed?.name'));
  expect(ui,contains("Key('waffra-sms-any-keyword')"));
  expect(ui,contains("Key('waffra-sms-advanced-rule-edit')"));
  expect(ui,contains('WaffraSmsLocalRules.validate(rule)'));
  expect(home,contains('Future<bool> _learnSafeSmsRule({'));
  expect(home,contains('await store.write(_smsRuleOwnerKey,[...prior,candidate]);'));
  expect(home,contains('if(!learned&&mounted)await _openSmsRules('));
  expect(home,contains('if(!exists&&!learned&&mounted){'));
  expect(home,contains('await bulkSmsSheet(initialText:body,'));
 });
}

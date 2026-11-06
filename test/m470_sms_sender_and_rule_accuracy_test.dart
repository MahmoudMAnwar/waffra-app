import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M470 #16 transfer learns only words present in the original SMS',(){
  const original='Credit Transfer via Alinma Bank\nAmount: SAR 1900.00';
  final proposed=WaffraSmsLocalRules.suggestedRule(
   body:original,sender:'AlinmaBank',kind:'transfer');
  expect(proposed,isNotNull);
  expect(proposed!.resolvedKind,'transfer');
  expect(proposed.keywords,isNot(contains('خصم')));
  expect(proposed.keywords,everyElement(isNotEmpty));
  expect(WaffraSmsLocalRules.matches(
   proposed,original,sender:'AlinmaBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(
   proposed,original,sender:'AnotherSender'),isFalse);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:original,sender:'AlinmaBank',kind:'expense',
   category:'مصروفات / غير مصنف'),isNull);
  const wrong=WaffraSmsLocalRule(
   id:'bad_transfer_expense',name:'Bad classification',
   kind:'transfer',income:false,keywords:['خصم'],sender:'AlinmaBank');
  expect(WaffraSmsLocalRules.matches(
   wrong,original,sender:'AlinmaBank'),isFalse);
 });

 test('M470 #16 seeded editor cannot fall back to an unrelated keyword',(){
  final source=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(source,isNot(contains('selected.add(seedChoices.first)')));
  expect(source,contains('selected.clear();'));
  expect(source,contains('final previewMessages=seed!=null?'));
  expect(source,contains('WaffraBankSmsFactsParser.parse(seed)'));
  expect(source,contains('WaffraSmsLocalRules.matches('));
  expect(source,contains('القاعدة لا تطابق المرسل أو الرسالة الأصلية'));
 });

 test('M470 #12 sender summary is RTL-isolated and uses approved copy',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('رسائل بانتظار المراجعة'));
  expect(home,isNot(contains(' رسائل تحتاج فرز')));
  expect(home,contains('textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl'));
  expect(home,contains(r'\u2068$count\u2069'));
 });
}

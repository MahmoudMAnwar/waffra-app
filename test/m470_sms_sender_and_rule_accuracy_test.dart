import 'dart:io';
import 'support/waffra_main_source.dart';
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
   kind:'transfer',income:false,category:'',keywords:['خصم'],sender:'AlinmaBank');
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
  final home=readWaffraMainSourceForContracts();
  expect(home,contains('رسائل بانتظار المراجعة'));
  expect(home,isNot(contains(' رسائل تحتاج فرز')));
  expect(home,contains('textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl'));
  expect(home,contains(r'\u2068$count\u2069'));
 });

 test('M470 #5/#6 account action stays beside date with preserved entry state',(){
  final home=readWaffraMainSourceForContracts();
  final anchor=home.indexOf('Future<void> entrySheet(');
  final editor=home.substring(anchor,home.indexOf('Future<void> showReceipt(',anchor));
  // #416/#418 supersede the old date-adjacent duplicate account button.
  // Provider and child selection remain mandatory ABOVE the full-width date.
  expect(editor,contains("m470-home-manual-provider-"));
  expect(editor,contains("m470-home-manual-account-"));
  expect(editor,contains("onChanged:chosenManualProvider==null||"));
  expect(editor,contains("chosenManualAccount=null; // A parent alone is not a money account."));
  expect(editor,contains("createAccountInsideEntryDropdown(mainProvider:true)"));
  expect(editor,contains("createAccountInsideEntryDropdown(mainProvider:false)"));
  expect(editor,contains("Expanded(child:dateAction())"));
  expect(editor,contains("if(!income&&waffraHasSelectableBudget(namedBudgets))"));
  expect(editor,isNot(contains("Expanded(child:accountAction())")));
 });
}

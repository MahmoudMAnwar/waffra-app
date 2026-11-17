import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M1031 safe post-save category hints never manufacture contradictory financial rules',(){
  final income=WaffraSmsLocalRules.manualCategoryPattern(
   description:'ستاربكس',category:'مصروفات مقهى',income:true);
  final expense=WaffraSmsLocalRules.manualCategoryPattern(
   description:'ستاربكس',category:'مصروفات مقهى',income:false);
  expect(income,isNotNull);
  expect(expense,isNotNull);
  final result=WaffraSmsLocalRules.upsertLearned(
   existing:[income!],candidate:expense!);
  expect(result,hasLength(1));
  expect(result.single.resolvedKind,'income');
  expect(result.single.autoPost,isFalse);
 });
 test('M1031 verified manual, bank review and background saves record encrypted learning receipts',(){
  final rules=File('lib/waffra_home_sms_rules.part.dart').readAsStringSync();
  final store=File('lib/waffra_sms_local_rules.dart').readAsStringSync();
  final sheet=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final confirmation=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final background=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(rules,contains('Future<void> _m1031RecordConfirmedLearning('));
  expect(store,contains('Future<bool> recordConfirmedFinanceLearning('));
  expect(store,contains('waffra_sms_confirmed_finance_learning_v1_'));
  expect(store,contains('Future<Map<String,int>> confirmedFinanceLearningCounts('));
  expect(store,contains("'sourceTotals':bySource"));
  final settings=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(settings,contains('m1031-confirmed-learning-counts'));
  expect(settings,contains('confirmedFinanceLearningCounts(widget.ownerKey)'));
  expect(settings,contains('قواعد كلمات آمنة قابلة لإعادة الاستخدام'));
  expect(store,contains('await _storage.write(key:key,value:next)'));
  expect(store,contains('if(reloaded!=next)'));
  expect(sheet.split('await _m1031RecordConfirmedLearning(result);').length-1,3);
  // A failure in optional safe-pattern extraction cannot prevent the owner
  // encrypted record of the already committed finance transaction.
  expect(sheet.split('await _m1031RecordConfirmedLearning(result);\n      await _learnManualCategoryPreference(result);').length-1,3);
  expect(confirmation,contains('await _m1031RecordConfirmedLearning(reviewed);\n    await _learnManualCategoryPreference(reviewed);'));
  expect(confirmation,contains('await _m1031RecordConfirmedLearning(reviewed);'));
  expect(background,contains('await store.recordConfirmedFinanceLearning('));
  expect(background,contains('await store.learnReviewedCandidates(owner,[safe]);'));
  expect(store,contains('rule.resolvedKind!=candidate.resolvedKind'));
 });
 test('M1031 outgoing bank transfer is expense suggestion, explicitly confirmable not AutoPost',(){
  const body='حوالة صادرة بمبلغ 200 ريال بتاريخ 16/11/2026 10:14';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(facts.requiresBeneficiaryReview,isTrue);
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
  expect(facts.canOwnerConfirmAsIncomeExpense,isTrue);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:body,localKind:'transfer'),'expense');
 });
 test('M1031 incoming and own-account transfer retain true direction',(){
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:'حوالة واردة بمبلغ 400 ريال بتاريخ 16/11/2026 10:14'),'income');
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:'تحويل بين حساباتي بمبلغ 150 ريال'),'transfer');
 });
 test('M1031 pending and OTP never receive unsafe green financial prediction',(){
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:'حوالة صادرة بمبلغ 100 ريال لم تتم',localKind:'expense'),isNull);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:'رمز التحقق 123456',localKind:'income'),isNull);
  expect(WaffraBankSmsFactsParser.reviewSuggestedKind(
   body:'تم خصم 100 ريال من حسابك رمز التحقق 123456',
   localKind:'expense',sensitiveOtp:true),isNull);
 });
 test('M1031 all three review surfaces and background share same predictor',(){
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  final notice=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  final bg=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  for(final src in [inbox,notice,bg]){
   expect(src,contains('WaffraBankSmsFactsParser.reviewSuggestedKind('));
  }
  expect(File('lib/waffra_approved_notifications.dart').readAsStringSync(),
   contains('مقترح مصروف • بانتظار التأكيد'));
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(review,contains('!facts.canOwnerConfirmAsIncomeExpense'));
  expect(review,contains('String? ownerBlocker()=>WaffraBankSmsFactsParser.ownerConfirmationBlocker('));
  expect(review,contains('expectedAccountGeneration:chosen.generation'));
  expect(bg,contains('!facts.canAutoPostAsIncomeExpense'));
 });
}

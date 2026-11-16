import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
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
  expect(review,contains('understood&&facts.canOwnerConfirmAsIncomeExpense'));
  expect(review,contains('expectedAccountGeneration:chosen.generation'));
  expect(bg,contains('!facts.canAutoPostAsIncomeExpense'));
 });
}

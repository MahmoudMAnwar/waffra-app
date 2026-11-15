import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

/// M985/#698: synthetic bank evidence and executable form safety contracts.
/// Source checks complement, never substitute, Android two-phone UAT.
void main(){
 test('M985 masked Saudi account suffix uses Arabic/Persian digits',(){
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'شراء بمبلغ 50 ريال من حساب ****١٢٣٤',income:false),'1234');
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'راتب 5000 ريال إلى الحساب ****٤٣٢١',income:true),'4321');
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'شراء بمبلغ 40 ريال card ending in ۱۲۳۴',income:false),'1234');
 });
 test('M985 never guesses account digits from OTP/ref or opposing direction',(){
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'رمز التحقق 1234 لحساب ****5678',income:false),isNull);
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'شراء بمبلغ 125 ريال رقم العملية 9876',income:false),isNull);
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'شراء بمبلغ 125 ريال من حساب ****1234 إلى حساب ****5678',
   income:false),'1234',reason:'Source is the only candidate for a verified debit');
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'حوالة صادرة بمبلغ 100 ريال من حساب ****1234',income:false),isNull);
  expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
   'راتب 5000 ريال إلى حساب ****1234',income:false),isNull);
 });
 test('M985 cancelled, declined and reversed purchases cannot be posted',(){
  for(final text in <String>[
   'تم الغاء عملية شراء بمبلغ 100 ريال من حساب ****1234',
   'Card purchase declined 95 SAR account ****1234',
   'شراء بمبلغ 100 ريال ملغاة من حساب ****1234',
   'Purchase reversed amount 100 SAR account ****1234',
   'شراء بمبلغ 100 ريال غير ناجحة من حساب ****1234',
  ]){
   final facts=WaffraBankSmsFactsParser.parse(text);
   expect(facts.pending,isTrue,reason:text);
   expect(facts.canAutoPostAsIncomeExpense,isFalse,reason:text);
   expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
    text,income:false),isNull);
  }
 });
 test('M985 reference and masked identity can warn, never silently dedupe',(){
  const a='شراء 19 ريال من حساب ****1234 رقم العملية: ABCD-112233';
  const same='شراء 19 ريال من حساب ****١٢٣٤ رقم العملية: ABCD-112233';
  const different='شراء 19 ريال من حساب ****5678 رقم العملية: ABCD-112233';
  const newRef='شراء 19 ريال من حساب ****1234 رقم العملية: OTHER-445566';
  expect(WaffraBankSmsFactsParser.sameReferenceAccountHint(a,same),isTrue);
  expect(WaffraBankSmsFactsParser.sameReferenceAccountHint(a,different),isFalse);
  expect(WaffraBankSmsFactsParser.sameReferenceAccountHint(a,newRef),isFalse);
  expect(WaffraBankSmsFactsParser.sameReferenceAccountHint(
   'شراء 19 ريال من حساب ****1234',same),isFalse);
 });
 test('M985 correction fills separate manual editor and protects source',(){
  final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final actions=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(editor,contains('final manualReviewBody=!sms&&initial==null?reviewedOriginalSms:null'));
  expect(editor,contains('final manualReviewSafeMoney='));
  expect(editor,contains('final manualReviewDate='));
  expect(editor,contains('final manualReviewTitle='));
  expect(editor,contains('final fallback=reviewedIncomeOverride?'));
  expect(editor,contains('chosenManualProvider=existing.single.id'));
  expect(editor,contains('suggestedAccountLastFour('));
  expect(editor,contains('WaffraSaudiFinancialProviders.wallet'));
  expect(editor,contains('bankReferenceReplay||entries.any('));
  expect(actions,contains('await entrySheet(manualIncomeOverride:kind=='));
  expect(actions,contains('reviewedOriginalSms:body,reviewedSender:sender'));
  expect(actions,contains('if(facts.kind==expected&&!facts.pending)'));
  expect(actions,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
 });
 test('M985 corrected transfers show amount/date and require manual accounts',(){
  final route=File('lib/waffra_home_verified_account_flows.part.dart')
   .readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  expect(route,contains('Future<void> openReviewedSmsManualTransfer('));
  expect(route,contains('initialSarMinor:safeAmount'));
  expect(route,contains('initialOccurredDate:confirmedDate'));
  expect(route,contains('requireSmsDateConfirmation:confirmedDate==null'));
  expect(route,contains('originalSmsText:body'));
  expect(route,contains('await api.transfer(id:draft.requestId'));
  expect(route,isNot(contains('await WaffraAutoSms.acknowledgeCommitted([id])')));
  expect(form,contains('initialSarMinor'));
  expect(form,contains('initialOccurredDate'));
  expect(form,contains('widget.requireSmsDateConfirmation&&!smsDateConfirmed'));
 });
 test('M985 rule preview evaluates owner conflicts without writing',(){
  final rules=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(rules,contains('final conflicts=previewMatches.where('));
  expect(rules,contains('final statusBlocked=previewMatches.where('));
  expect(rules,contains('final otpSensitive=previewMatches.where('));
  expect(rules,contains('old.id!=existing?.id'));
  expect(rules,contains('they stay in review.'));
 });
}

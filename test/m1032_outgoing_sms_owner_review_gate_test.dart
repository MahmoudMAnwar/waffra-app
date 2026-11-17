import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main(){
 test('M1032 bank suffix reconciliation and rule capacity are explicit in owner paths',(){
  final settings=File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
  final controller=File('lib/waffra_home_verified_account_flows.part.dart').readAsStringSync();
  final inbox=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final rules=File('lib/waffra_sms_local_rules.dart').readAsStringSync();
  final evidence=File('lib/waffra_sms_account_learning.dart').readAsStringSync();
  expect(settings,contains('onVerifiedBankSuffixChanged'));
  expect(controller,contains('disableAccountBoundPosting('));
  expect(controller,contains('invalidateAccount('));
  expect(evidence,contains('Future<int> invalidateAccount('));
  expect(inbox,contains('if(currentSuffix!=matched.accountSuffix)'));
  expect(inbox,contains('await keepForReview(candidate);continue;'));
  expect(rules,contains('blockedConflicts:conflict,blockedCapacity:capacity'));
  expect(rules,contains('Future<int> disableAccountBoundPosting('));
 });

 test('M1032 outgoing AlRajhi transfer can be approved by owner after true SAR/date/category review',(){
  const sms='حوالة صادرة\nالمبلغ: ﷼ 1900.00\n2026-11-01 08:46';
  final facts=WaffraBankSmsFactsParser.parse(sms);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(facts.canOwnerConfirmAsIncomeExpense,isTrue);
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
  final amount=WaffraSmsCurrencies.originalAmount(sms);
  expect(amount?.currency,'SAR');
  expect(amount?.amount,1900);
  expect(WaffraBankSmsFactsParser.ownerConfirmationBlocker(
   facts:facts,requiresSeparateReview:false,amountVerifiedSar:true,
   timestampVerified:true,leafVerified:true),isNull);
 });
 test('M1032 category is the blocker when the suggested leaf is unverified',(){
  final facts=WaffraBankSmsFactsParser.parse(
   'حوالة صادرة\nالمبلغ: SAR 1900.00');
  expect(WaffraBankSmsFactsParser.ownerConfirmationBlocker(
   facts:facts,requiresSeparateReview:false,amountVerifiedSar:true,
   timestampVerified:true,leafVerified:false),'category');
 });
 test('M1032 no bypass of amount, date, OTP, or multi-event safety',(){
  final facts=WaffraBankSmsFactsParser.parse(
   'حوالة صادرة\nالمبلغ: SAR 1900.00');
  String? check({bool amount=true,bool date=true,bool multi=false})=>
   WaffraBankSmsFactsParser.ownerConfirmationBlocker(
    facts:facts,requiresSeparateReview:multi,amountVerifiedSar:amount,
    timestampVerified:date,leafVerified:true);
  expect(check(amount:false),'amount_or_currency');
  expect(check(date:false),'date');
  expect(check(multi:true),'multi_event');
  final otp=WaffraBankSmsFactsParser.parse(
   'حوالة صادرة SAR 1900.00 رمز التحقق 123456');
  expect(WaffraBankSmsFactsParser.ownerConfirmationBlocker(
   facts:otp,requiresSeparateReview:false,amountVerifiedSar:true,
   timestampVerified:true,leafVerified:true),'direction');
 });
 test('M1032 owner review uses verified bank facts, and shows the actual missing field',(){
  final source=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(source,contains('String? ownerBlocker()=>WaffraBankSmsFactsParser.ownerConfirmationBlocker('));
  expect(source,contains('canConfirm=ownerBlocker()==null;'));
  expect(source,contains('اختر قسمًا رئيسيًا وفرعيًا نشطين'));
  expect(source,isNot(contains('(parsed.amount!-originalAmount.amount).abs()<0.00001')));
  expect(source,isNot(contains('parsed.income==expectedIncome')));
  expect(source,contains('final valid=categories.where((c)=>c.income==income&&c.isSubcategory'));
  expect(source,contains('bankSmsHasUnverifiedTimestamp(body)'));
  expect(source,contains('bankSmsHash(body,nativeId:id)'));
 });
}

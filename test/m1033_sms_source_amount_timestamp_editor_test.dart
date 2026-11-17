import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
 const walletSms='عملية حوالة مالية صادرة مقبولة\n'
  'خصمت من محفظة: **8308\n'
  'إلى: عميل مستفيد\n'
  'أيبان: **9288\n'
  'القيمة: SAR 882\n'
  'الرسوم: SAR 0.58\n'
  'في: 15:13 02-11-2026\n'
  'الرقم المرجعي: EPY26306LLRVYG7H';
 const internalSms='حوالة داخلية صادرة\n'
  'من: مرسل تجريبي\n'
  'مبلغ: SAR 60.00\n'
  'إلى: مستفيد تجريبي\n'
  'حساب:**8647\n'
  'رسوم:0\n'
  'الرقم المرجعي: FT26319QPRW3\n'
  'في:15-11-2026 10:14';

 test('M1033 wallet principal is SAR 882, fee is not principal or .5', () {
  final principal=WaffraSmsCurrencies.originalAmount(walletSms);
  final facts=WaffraBankSmsFactsParser.parse(walletSms);
  expect(principal?.currency,'SAR');
  expect(principal?.amount,882);
  expect(facts.fee,closeTo(0.58,0.000001));
  expect(facts.kind,WaffraBankOperationKind.expense);
  // Confirmed outgoing-to-another-person is NOT an own-account transfer.
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
  expect(facts.pending,isFalse);
  expect(WaffraSmsCurrencies.requiresReviewForSarLedger(walletSms),isFalse);
 });

 test('M1033 bank wallet time before full-year date is source verified',(){
  expect(bankSmsDate(walletSms),DateTime(2026,11,2,15,13));
  expect(bankSmsHasUnverifiedTimestamp(walletSms),isFalse);
  expect(bankSmsDate('في: 15:13 02-11-2026'),
   DateTime(2026,11,2,15,13));
  expect(bankSmsDate('في: 15:13 31-02-2026'),isNull);
  expect(bankSmsHasUnverifiedTimestamp('في: 15:13 31-02-2026'),isTrue);
 });

 test('M1033 full-year date before time is source verified',(){
  final principal=WaffraSmsCurrencies.originalAmount(internalSms);
  expect(principal?.currency,'SAR');
  expect(principal?.amount,60);
  expect(bankSmsDate(internalSms),DateTime(2026,11,15,10,14));
  expect(bankSmsHasUnverifiedTimestamp(internalSms),isFalse);
 });

 test('M1033 ambiguous two-digit-year transfer dates still blocked',(){
  final sourceDate=bankSmsDate('حوالة صادرة 26/10/25 12:34',
   referenceDate:DateTime(2026,10,31));
  expect(sourceDate,isNull);
  expect(bankSmsHasUnverifiedTimestamp('حوالة صادرة 26/10/25 12:34',
   referenceDate:DateTime(2026,10,31)),isTrue);
 });

 test('M1033 display prefills do not authorize posting or change drafts',(){
  final editor=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final smsReview=File('lib/waffra_home_sms_confirmation.part.dart')
   .readAsStringSync();
  expect(editor,contains('(directionKnown||reviewedSmsCorrection)&&'));
  expect(editor,isNot(contains('directionKnown&&factsSms!.canAutoPostAsIncomeExpense')));
  expect(editor,contains("sourceAmount?.currency=='SAR'"));
  expect(editor,contains('WaffraSmsCurrencies.originalAmount(initialSms)'));
  expect(editor,contains("smsEditorDraft?['amount'] as String?"));
  expect(editor,contains('smsDateConfirmed'));
  expect(editor,contains('commitConfirmedSms('));
  expect(smsReview,contains('reviewedAccount?.ids?.single!=null'));
  expect(smsReview,contains('ownerBlocker()==null'));
  expect(smsReview,contains('bankSmsHasUnverifiedTimestamp(body)'));
  expect(smsReview,contains('userConfirmed:true'));
 });
}

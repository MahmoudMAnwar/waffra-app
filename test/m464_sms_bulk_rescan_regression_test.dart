import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';

void main() {
 test('M464 native SMS history has a resumable queue beyond 100',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(native,contains('private const val maxCandidates = 1000'));
  expect(native,contains('historyScannedCount'));
  expect(native,contains('historyAddedCount'));
  expect(native,contains('fun scanProgress(context: Context)'));
  expect(native,contains('historyCursorAt'));
  expect(native,contains('historyCursorId'));
  expect(activity,contains('"autoSmsScanProgress"'));
  expect(bridge,contains("importConsentMonthChecked()"));
  expect(bridge,contains("scanProgress()"));
  expect(bridge,contains("'autoSmsScanProgress'"));
 });

 test('M464 rescan signals active state and returns cumulative counts',(){
  final app=File('lib/main.dart').readAsStringSync();
  expect(app,contains('bool _autoSmsRescanRunning=false;'));
  expect(app,contains('Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{'));
  expect(app,contains('await _refreshAutoSmsInbox(importMonth:true);'));
  expect(app,contains('await WaffraAutoSms.importConsentMonthChecked()'));
  expect(app,contains('waffra-auto-sms-review-refresh'));
  expect(app,contains('جارٍ الآن فحص الرسائل'));
  expect(app,contains("snapshot?['pending']"));
 });

 test('M464 review supports both sender and individual multi-selection',(){
  final app=File('lib/main.dart').readAsStringSync();
  final begin=app.indexOf(' Future<void> _openAutoSmsInbox()async{');
  final end=app.indexOf(' Widget _autoSmsReviewCard(){',begin);
  expect(begin,greaterThan(0));
  expect(end,greaterThan(begin));
  final review=app.substring(begin,end);
  expect(review,contains('waffra-sms-select-all-visible'));
  expect(review,contains('waffra-sms-select-sender-'));
  expect(review,contains('waffra-sms-select-message-'));
  expect(review,contains('waffra-sms-bulk-exclude-selected'));
  expect(review,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(review,isNot(contains('WaffraAutoSms.acknowledge(batch)')));
  expect(review,contains('at+=100'));
  expect(review,contains('showWaffraDialog<bool>'));
  // Selected review entries are removed from Waffra's intake queue only.
  expect(review,isNot(contains('deleteAndroidSms')));
  expect(review,isNot(contains('commitConfirmedSms(')));
 });

 test('M464 bank suffix matching never confuses two same-bank accounts',(){
  const sameBank={'rajhi1':'1234','rajhi2':'5678'};
  final a=WaffraAccountContextPolicy.matchBankSms(
   sourceSuffix:'1234',destinationSuffix:null,incoming:false,
   classifiedIncomeOrExpense:true,verifiedSuffixByAccount:sameBank);
  expect(a.accountId,'rajhi1');
  expect(a.confident,isTrue);
  final unknown=WaffraAccountContextPolicy.matchBankSms(
   sourceSuffix:null,destinationSuffix:null,incoming:false,
   classifiedIncomeOrExpense:true,verifiedSuffixByAccount:sameBank);
  expect(unknown.accountId,isNull);
  expect(unknown.confident,isFalse);
  final collision=WaffraAccountContextPolicy.matchBankSms(
   sourceSuffix:'1234',destinationSuffix:null,incoming:false,
   classifiedIncomeOrExpense:true,
   verifiedSuffixByAccount:const {'rajhi1':'1234','rajhi2':'1234'});
  expect(collision.accountId,isNull);
  expect(collision.confident,isFalse);
 });
}

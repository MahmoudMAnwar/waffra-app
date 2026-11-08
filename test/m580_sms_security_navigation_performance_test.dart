import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 test('Arabic temporary code is security, not completed transfer or expense',(){
  const body='رمز مؤقت 123456 لتأكيد تحويل بمبلغ 400 ريال';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
  expect(facts.pending,isTrue);
  expect(facts.kind,WaffraBankOperationKind.uncertain);
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
 });

 test('English one-time password does not create a financial suggestion',(){
  const body='Verification code 112233 for transfer of 900 SAR';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(facts.pending,isTrue);
  expect(facts.kind,WaffraBankOperationKind.uncertain);
 });

 test('settled debit without OTP stays a finance candidate',(){
  const body='تم خصم 20 ريال من حساب **1234';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(facts.pending,isFalse);
 });

 test('mixed debit and challenge fails closed for user verification',(){
  const body='تم خصم 20 ريال. رمز التحقق 123456';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(facts.pending,isTrue);
  expect(facts.kind,WaffraBankOperationKind.uncertain);
 });

 test('tapping one notice avoids marshalling a full 1000 SMS queue',(){
  final main=File('lib/main.dart').readAsStringSync();
  final review=main.split(' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(review,contains('await WaffraAutoSms.pendingById(targetId)'));
  expect(review,contains('targetId==null?await WaffraAutoSms.pending()'));
  final bridge=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(bridge,contains("'pendingAutoBankSmsById',id"));
  final android=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(android,contains('"pendingAutoBankSmsById" -> {'));
  expect(android,contains('smsHistoryExecutor.execute {'));
  expect(android,contains('WaffraAutoSmsStore.pendingById(app, id)'));
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('fun pendingById(context: Context, id: String)'));
  expect(store,contains('if (row.optString("id") != id) continue'));
 });

 test('notification center never repeats a second review hero',(){
  final ui=File('lib/waffra_approved_notifications.dart')
   .readAsStringSync();
  expect(ui,contains("Key('m580-sender-filters')"));
  expect(ui,isNot(contains('m549-notification-review-hero')));
  expect(ui,contains("'excluded'=>widget.english?'Excluded • verification':'مستبعدة — رمز تحقق'"));
  expect(ui,contains("key:Key('m549-notification-message-'+notice.id)"));
 });
}

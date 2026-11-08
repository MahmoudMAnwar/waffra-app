import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_intelligence.dart';

void main(){
 test('Arabic temporary code is security, not completed transfer or expense',(){
  const body='رمز مؤقت 123456 لتأكيد تحويل بمبلغ 400 ريال';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(body),isTrue);
  expect(facts.pending,isTrue);
  expect(facts.kind,WaffraBankOperationKind.uncertain);
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
 });

 test('M591 all local classifiers agree on temporary Arabic verification',(){
  const otp='رمز مؤقت 123456 لتأكيد تحويل لمستفيد جديد بقيمة 75 ريال';
  expect(WaffraBankSmsFactsParser.isVerificationChallenge(otp),isTrue);
  expect(WaffraSmsIntelligence.isPendingOrUnconfirmed(otp),isTrue);
  final prediction=WaffraSmsIntelligence.classify(otp);
  expect(prediction.intent,WaffraSmsIntent.uncertain);
  expect(prediction.canAutoSuggestSar,isFalse);
  final finance=WaffraBankSmsFactsParser.parse(otp);
  expect(finance.canAutoPostAsIncomeExpense,isFalse);
 });

 test('M591 excluded labels are consistent across default and learned lists',(){
  final settings=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(settings,contains("'Excluded':'مستبعدة'"));
  expect(settings,contains("'Excluded messages':'الرسائل المستبعدة'"));
  expect(settings,isNot(contains("'Excluded':'مستثناة'")));
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

 test('re-login submit CTA keeps its width and feedback during secure KDF',(){
  final main=File('lib/main.dart').readAsStringSync();
  final button=main.split('FilledButton(onPressed:WaffraHaptics.tap(signingIn?null:_signIn)')[1]
   .split("key:const Key('m479-login-back-to-choice')")[0];
  expect(button,contains("Key('m585-login-submit-stable')"));
  expect(button,contains("minimumSize:const Size(218,48)"));
  expect(button,contains("'جارٍ تسجيل الدخول'"));
  expect(button,contains("CircularProgressIndicator("));
 });

 test('cold Home never shows a completely blank spinner-only body',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains("WaffraText(waffraIsEnglish?'Preparing secure finances…'"));
  expect(main,contains("'جارٍ تجهيز بياناتك المالية بأمان…'"));
  expect(main,contains(" !ready?RepaintBoundary("));
  expect(main,isNot(contains("!ready?const Center(child:CircularProgressIndicator())")));
 });

 test('canceling SMS review never triggers a redundant full encrypted SMS reread',(){
  final main=File('lib/main.dart').readAsStringSync();
  final review=main.split(' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  final cleanup=review.split('  }finally{').last;
  expect(cleanup,contains('_autoSmsReviewOpen=false;'));
  expect(cleanup,isNot(contains('unawaited(_refreshAutoSmsInbox());')));
 });

 test('monthly summary amount stays centered within the circle at narrow widths',(){
  final main=File('lib/main.dart').readAsStringSync();
  final summary=main.split(' Widget monthlySummaryCard(){')[1]
   .split(' Widget smartMoneyInsightsCard(){')[0];
  expect(summary,contains("Key('m584-monthly-summary-circle-value')"));
  expect(summary,contains("width:74,height:27"));
  expect(summary,contains('fit:BoxFit.scaleDown'));
  expect(summary,contains('alignment:Alignment.center'));
 });

 test('M590 review requires verified account BEFORE Yes, and never opens picker after Yes',(){
  final main=File('lib/main.dart').readAsStringSync();
  final preview=main.split(
   ' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(preview,contains("Key('m590-sms-choose-account-before-yes')"));
  expect(preview,contains('reviewedAccount?.ids?.single!=null'));
  expect(preview,contains('await reviewSmsAccountLinks([trial],smsSender:sender)'));
  expect(preview,contains('reviewedAccount=(ids:<String?>[id],generation:fresh.witness.generation)'));
  expect(preview,contains('selectedAccount:reviewedAccount!'));
  final writer=main.split(' Future<void> _m565ConfirmSms({')[1]
   .split(' Future<void> _reviewAutoSmsCandidates({')[0];
  expect(writer,contains('required ({List<String?>? ids,int? generation}) selectedAccount'));
  expect(writer,contains('final chosen=selectedAccount;'));
  expect(writer,isNot(contains('await reviewSmsAccountLinks([')));
  expect(writer,contains('allowDuplicateHashes:false'));
  expect(writer,contains('expectedAccountGeneration:chosen.generation'));
 });

 test('M596 foreign or malformed bank fees fail closed before money',(){
  for(final body in <String>[
   'تحويل بين حساباتي 19 ريال رسوم 0.58 USD',
   'تحويل بين حساباتي 19 ريال رسوم 0.581 ريال',
   'تحويل بين حساباتي 19 ريال رسوم -0.58 ريال',
   'transfer sent SAR 19 fees 0.58 AED',
   'تحويل بين حساباتي 19 ريال رسوم 0.58%',
  ]){
   final facts=WaffraBankSmsFactsParser.parse(body);
   expect(facts.pending,isTrue,reason:body);
   expect(facts.fee,isNull,reason:body);
   expect(facts.canAutoPostAsIncomeExpense,isFalse,reason:body);
  }
 });

 test('M596 coffee is an expense item, not a bank fee',(){
  const body='Coffee purchase debited 15 SAR from account **1234';
  final facts=WaffraBankSmsFactsParser.parse(body);
  expect(facts.kind,WaffraBankOperationKind.expense);
  expect(facts.pending,isFalse);
  expect(facts.fee,isNull);
 });

 test('M596 valid SAR fee stays explicit but is not auto-posted',(){
  final facts=WaffraBankSmsFactsParser.parse(
   'تحويل بين حسابات 19 ريال رسوم 0.58 ريال');
  expect(facts.kind,WaffraBankOperationKind.transfer);
  expect(facts.fee,0.58);
  expect(facts.pending,isFalse);
  expect(facts.canAutoPostAsIncomeExpense,isFalse);
 });

 test('M594 separate fee totals are exact halalas, not guessed money',(){
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:0.58),1958);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:190000,feeSar:0.58),190058);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:0.0),1900);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:null),isNull);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:0.001),isNull);
 });

 test('M594 fee-carrying SMS cannot silently save principal-only transfer',(){
  final src=File('lib/main.dart').readAsStringSync();
  final review=src.split(' Future<void> _reviewSmsAccountTransfer({')[1]
   .split(' /// M593: even with JSON decoded')[0];
  expect(review,contains('feeTotalMinor'));
  expect(review,contains("WaffraSmsAccountLearning.suffix4(facts.destinationSuffix)"));
  expect(review,contains("WaffraSmsAccountLearning.suffix4(facts.sourceSuffix)"));
  expect(review,contains("if(facts.fee!=null&&facts.fee!>0){"));
  expect(review,contains("throw StateError('Transfer fee requires atomic finance writer')"));
  expect(review,contains('WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
 });

 test('M592 bulk review keeps Waffra native policy, not phone SMS deletion',(){
  final main=File('lib/main.dart').readAsStringSync();
  final handler=main.split(
   ' Future<bool> _m592ExcludeNotificationSelection(')[1]
   .split(' Future<void> _m549OpenNotifications()async{')[0];
  expect(handler,contains('WaffraAutoSms.excludeSenders(senderNames)'));
  expect(handler,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(handler,contains('selected.every(pending.containsKey)'));
  expect(handler,isNot(contains('final blockedIds=')));
  expect(handler,contains('final bySender='));
  expect(handler,isNot(contains('await WaffraAutoSms.acknowledgeCommitted(')));
  expect(handler,isNot(contains('deleteAndroidSms')));
 });

 test('M593 manual and reviewed-SMS verified ledger mapping yields frames',(){
  final app=File('lib/main.dart').readAsStringSync();
  expect(app,contains('Future<List<MoneyEntry>> _m593BuildVerifiedEntries('));
  expect(app,contains('const batchSize=32;'));
  expect(app,contains('await Future<void>.delayed(const Duration(milliseconds:1))'));
  expect(app,contains('final verified=await _m593BuildVerifiedEntries(decoded);'));
  expect(app,contains('final updated=await _m593BuildVerifiedEntries(decoded);'));
 });

 test('M595 compact review has exact three selectable transaction types',(){
  final app=File('lib/main.dart').readAsStringSync();
  final review=app.split(
   ' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(review,contains("const <String>['income','expense','transfer']"));
  expect(review,contains("Key('m595-review-type-'+option)"));
  expect(review,contains("Key('m595-review-type-continue')"));
  expect(review,contains("Key('m595-review-single-exclude')"));
  expect(review,contains("reviewType=option;"));
  expect(review,contains("reviewedAccount=null;"));
  expect(review,contains("reviewedAccountName=null;"));
  expect(review,contains("if(decision=='correct-type'&&mounted&&reviewType!=null)"));
 });

 test('M595 correction must not auto-post, guess a transfer, or auto ACK',(){
  final app=File('lib/main.dart').readAsStringSync();
  final review=app.split(
   ' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  final corrected=review.split("if(decision=='correct-type'&&mounted&&reviewType!=null)")[1]
   .split("else if(decision=='exclude'&&mounted)")[0];
  expect(corrected,contains('await openVerifiedTransfer()'));
  expect(corrected,contains('await entrySheet(sms:true,initialSms:body,'));
  expect(corrected,contains("reviewedSender:sender,reviewedIncomeOverride:reviewType=='income'"));
  expect(corrected,contains('if(approved==true&&mounted)await openVerifiedTransfer()'));
  expect(corrected,contains('The message does not prove both accounts are yours'));
  final editor=app.split(' Future<void> entrySheet({')[1]
   .split(' Future<void> showReceipt(')[0];
  expect(editor,contains('String? reviewedSender,bool? reviewedIncomeOverride,'));
  expect(editor,contains("bool income=reviewedIncomeOverride??(smsEditorDraft?['income'] as bool?)"));
  expect(corrected,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(corrected,isNot(contains('commitConfirmedSms(')));
  expect(corrected,isNot(contains('excludeMessages(')));
  final buttons=review.split("if(!sensitive)...[")[1]
   .split("if(!sensitive)Padding(")[0];
  expect(buttons,isNot(contains("await _financeAuthority.commitConfirmedSms(")));
  expect(buttons,isNot(contains("WaffraAutoSms.acknowledgeCommitted(")));
 });

 test('M587 bank transfer shows exactly three non-posting choices',(){
  final main=File('lib/main.dart').readAsStringSync();
  final review=main.split(
   ' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
   .split(' void _receiveSharedSms(){')[0];
  expect(review,contains("Key('m587-sms-transfer-yes')"));
  expect(review,contains("Key('m587-sms-transfer-no')"));
  expect(review,contains("Key('m587-sms-transfer-exclude')"));
  expect(review,contains("Navigator.pop(dialog,'transfer-manual')"));
  expect(review,contains("await _reviewSmsAccountTransfer(item:selected,facts:facts)"));
  expect(review,contains("await entrySheet(scannedIncome:kind=='income')"));
  expect(review,contains("await WaffraAutoSms.excludeMessages([id])"));
  final writer=main.split(' Future<void> _reviewSmsAccountTransfer({')[1]
   .split(' /// M565: a reviewed bank SMS posts only')[0];
  expect(writer,contains('amountMinor:verifiedMinor'));
  expect(writer,contains('accounts:accounts,english:waffraIsEnglish'));
  expect(writer,contains('userConfirmed:true'));
  expect(writer,contains('WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
 });
 test('notification center never repeats a second review hero',(){
  final ui=File('lib/waffra_approved_notifications.dart')
   .readAsStringSync();
  expect(ui,contains("Key('m580-sender-filters')"));
  expect(ui,isNot(contains('m549-notification-review-hero')));
  expect(ui,contains("'otpReview'=>widget.english?'Verification • review only':"));
  expect(ui,contains("key:Key('m549-notification-message-'+notice.id)"));
 });
}

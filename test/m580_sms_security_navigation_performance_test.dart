import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_intelligence.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

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

 test('M622 cold Home only displays actual verified balances at once',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('child:!ready&&_financeLoadFailure==null?'));
  expect(main,contains('balance:_m467ShownBalance()'));
  expect(main,isNot(contains('Widget _m622ImmediateHomeSurface()=>')));
  expect(main,isNot(contains("'بنفتح الرئيسية…'")));
  expect(main,isNot(contains("'Opening your dashboard…'")));
  expect(main,isNot(contains("const Text('••••'")));
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
  // The first-account path must verify the freshly selected/created ID
  // against a live SQLCipher witness before enabling confirmation.
  expect(preview,contains('final fresh=await bridge.readVerifiedAccounts();'));
  expect(preview,contains('if(active.length!=1)return;'));
  expect(preview,contains('reviewedAccount=(ids:<String?>[pickedId],'));
  expect(preview,contains('generation:fresh.witness.generation);'));
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
   'تحويل بين حساباتي 19 ريال رسوم 0.58 usd',
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

 test('M594 fee and transfer save together, with review before ACK',(){
  final src=File('lib/main.dart').readAsStringSync();
  final review=src.split(' Future<void> _reviewSmsAccountTransfer({')[1]
   .split(' /// M593: even with JSON decoded')[0];
  expect(review,contains('feeTotalMinor'));
  expect(review,contains("WaffraSmsAccountLearning.suffix4(facts.destinationSuffix)"));
  expect(review,contains("WaffraSmsAccountLearning.suffix4(facts.sourceSuffix)"));
  expect(review,contains('if(fee!=null&&fee>0){'));
  expect(review,contains('WaffraBankSmsFactsParser.extraDebitMinor('));
  expect(review,contains('if(feeMinor==null||feeMinor<=0||fullDebit==null||!mounted){'));
  expect(review,contains("throw StateError('Ambiguous SAR bank fee must be reviewed.')"));
  expect(review,contains("if(selected!='included'&&selected!='separate'){"));
  expect(review,contains("throw StateError('Fee confirmation was not granted.')"));
  expect(review,contains('await api.transferReviewedSmsWithFee('));
  expect(review,contains("feeIncludedInDebit:selected=='included'"));
  expect(review,contains('messageHash:id'));
  expect(review,contains('await api.transfer(id:draft.requestId,'));
  expect(review,contains('ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
  expect(review.indexOf('await api.transferReviewedSmsWithFee('),
   lessThan(review.indexOf('ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id])')));
 });

 test('M600 mixed financial purchase and OTP is never a learned exclusion',(){
  const mixed='Card Purchase SAR 75.00 رمز التفعيل 482913';
  final facts=WaffraBankSmsFactsParser.parse(mixed);
  expect(facts.kind,WaffraBankOperationKind.uncertain);
  expect(facts.pending,isTrue);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:mixed,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true),isNull);
  const existing=WaffraSmsLocalRule(
   id:'otp_rule',name:'OTP',kind:'excluded',income:false,
   category:'',sender:'AlRajhiBank',
   keywords:['رمز التفعيل'],matchAll:false);
  expect(WaffraSmsLocalRules.resolveSpecial(
   body:mixed,sender:'AlRajhiBank',bankKind:facts.kind,custom:[existing]),isNull);
  const onlyOtp='رمز التفعيل الخاص بك هو 482913، لا تشارك الرمز';
  final safe=WaffraSmsLocalRules.suggestedRule(
   body:onlyOtp,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
  expect(safe,isNotNull);
  expect(safe!.toJson().toString(),isNot(contains('482913')));
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
  expect(app,contains('const batchSize=96;'));
  expect(app,contains('await Future<void>.delayed(Duration.zero)'));
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
  // M618 moves actions into a revised layout. Keep the behavioral guards
  // independent of a specific widget tree or old conditional delimiter.
  expect(review,contains("Key('m565-sms-yes-confirm')"));
  expect(review,contains("Key('m565-sms-no-edit')"));
  expect(review,contains("Key('m595-review-single-exclude')"));
  expect(review,contains('reviewedAccount?.ids?.single!=null'));
  expect(corrected,isNot(contains("await _financeAuthority.commitConfirmedSms(")));
  // A corrected SMS may be ACKed only AFTER the verified SQLCipher writer
  // has recorded its exact source hash; choosing a different type alone
  // never ACKs or posts a transaction.
  expect(corrected,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(corrected,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(corrected.indexOf('if(smsHashes.contains(bankSmsHash(body)))'),
    lessThan(corrected.indexOf('await WaffraAutoSms.acknowledgeCommitted([id])')));
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
 test('M597 exact halalah transfer fee remains a separate bank charge',(){
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:0.58),1958);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:190000,feeSar:0.58),190058);
  expect(WaffraBankSmsFactsParser.extraDebitMinor(
   principalMinor:1900,feeSar:0.005),isNull);
 });

 test('M597 source SMS transfer, fee expense and hash commit atomically',(){
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
   .readAsStringSync();
  final writer=File('lib/storage/waffra_unified_finance_writer.dart')
   .readAsStringSync().split('appendReviewedSmsTransferWithFee({')[1]
   .split('  /// Called AFTER explicit confirmation')[0];
  final api=File('lib/storage/waffra_verified_accounts_api.dart')
   .readAsStringSync();
  final main=File('lib/main.dart').readAsStringSync()
   .split(' Future<void> _reviewSmsAccountTransfer({')[1]
   .split(' /// M593: even with JSON')[0];
  expect(bridge,contains('commitReviewedSmsTransferWithFee({'));
  expect(api,contains('transferReviewedSmsWithFee({'));
  expect(writer,contains('withExclusiveAccess(() async {'));
  expect(writer,contains('snapshot.store.transaction(() async {'));
  expect(writer,contains('await WaffraAccountsSchema.requireReady('));
  expect(writer,contains('await accounts.transfer('));
  expect(writer,contains('INSERT INTO fresh_finance_entries'));
  expect(writer,contains('INSERT INTO fresh_finance_account_entry_links'));
  expect(writer,contains('INSERT INTO fresh_finance_sms_hashes'));
  expect(writer,contains('snapshot.commit('));
  expect(writer.indexOf('await accounts.transfer('),
   lessThan(writer.indexOf('INSERT INTO fresh_finance_entries')));
  expect(writer.indexOf('INSERT INTO fresh_finance_entries'),
   lessThan(writer.indexOf('INSERT INTO fresh_finance_sms_hashes')));
  expect(writer.indexOf('INSERT INTO fresh_finance_sms_hashes'),
   lessThan(writer.indexOf('snapshot.commit(')));
  expect(writer,contains('feeIncludedInDebit ? principalMinor - feeMinor : principalMinor'));
  expect(writer,contains('Existing transfer must never be double charged.'));
  expect(main,contains('transferReviewedSmsWithFee('));
  expect(main,contains('messageHash:id'));
  expect(main,contains('showDatePicker('));
  expect(main,contains('showTimePicker('));
  expect(main.indexOf('transferReviewedSmsWithFee('),
   lessThan(main.indexOf('acknowledgeCompletedTransfer([id])')));
 });

}

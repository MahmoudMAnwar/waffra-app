import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show BankParser;
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M983/#689 synthetic-only: owner selected type is not finance authority.
void main(){
 test('M983 tapped income expense and transfer have distinct bank evidence',(){
  final cases=<(String,WaffraBankOperationKind)>[
   ('تم إيداع راتب 7000 ريال في حسابك',WaffraBankOperationKind.income),
   ('شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم',
     WaffraBankOperationKind.expense),
   ('حوالة صادرة بمبلغ 140 ريال',WaffraBankOperationKind.transfer),
  ];
  for(final item in cases){
   final facts=WaffraBankSmsFactsParser.parse(item.$1);
   expect(facts.kind,item.$2);
   expect(facts.pending,isFalse);
   final rules=WaffraSmsLocalRules.matchAllFourKinds(
    body:item.$1,sender:'TestBank');
   expect(rules.where((r)=>r.resolvedKind==switch(item.$2){
    WaffraBankOperationKind.income=>'income',
    WaffraBankOperationKind.expense=>'expense',
    _=>'transfer',
   }).isNotEmpty,isTrue);
  }
 });

 test('M983 SMS data is suggested only; incomplete fields do not imply commit',(){
  final parsed=BankParser.parse('شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم');
  expect(parsed.income,isFalse);
  final form=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  expect(form,contains('final directionKnown='));
  expect(form,contains('final safeSmsTitle='));
  expect(form,contains('final safeSmsAmount='));
  expect(form,contains('sourceAmount?.currency==\'SAR\''));
  expect(form,contains('reviewedIncomeOverride==(factsSms.kind==WaffraBankOperationKind.income)'));
  expect(form,contains('editorFourWay='));
  expect(form,contains('matchedRules:editorFourWay'));
  expect(form,contains('if(sms&&initial==null&&reviewedIncomeOverride!=null)'));
  expect(form,contains('waffraTransactionTitleAllowed(parsedSms.title)'));
  expect(form,contains('chosenManualAccount'));
  expect(form,contains('userConfirmed:true'));
 });

 test('M983 Inbox offers exact type chips and refreshes native list after save',(){
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(inbox,contains("for(final kind in const <String>['income','expense','transfer'])"));
  expect(inbox,contains("Key('m983-sms-direct-'+kind+'-'+index.toString())"));
  expect(inbox,contains('_m983OpenSmsTypedTemplate(id:id,kind:kind)'));
  expect(inbox,contains('if(mounted)await _refreshAutoSmsInbox();'));
  expect(inbox,contains('final fresh=WaffraSmsReviewGroups.from(_autoSmsPending,'));
  expect(inbox,contains('bySender..clear()..addAll(fresh.bySender)'));
  expect(inbox,contains('senders..clear()..addAll(fresh.senders)'));
  expect(inbox,contains('selectedIds.removeWhere((selected)=>!active.contains(selected))'));
  expect(inbox,contains("suggestedKind=='income'"));
  expect(inbox,contains("suggestedKind=='expense'"));
  expect(inbox,contains("suggestedKind=='transfer'"));
 });

 test('M983 direct reviewer uses exact owner native ID, never financial inference',(){
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final start=review.indexOf('Future<void> _m983OpenSmsTypedTemplate({');
  final end=review.indexOf('Future<void> _reviewAutoSmsCandidates(',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final snippet=review.substring(start,end);
  expect(snippet,contains('WaffraAutoSms.pendingById(id)'));
  expect(snippet,contains("if(row['id']!=id)"));
  expect(snippet,contains("if(kind=='transfer'){"));
  expect(snippet,contains('await _reviewSmsAccountTransfer(item:row,facts:facts)'));
  expect(snippet,contains('await openVerifiedTransfer()'));
  expect(snippet,contains("await entrySheet(sms:true,initialSms:body,"));
  expect(snippet,contains("reviewedSender:sender,reviewedIncomeOverride:kind=='income'"));
  expect(snippet,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(snippet,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(snippet,contains("await entrySheet(manualIncomeOverride:kind=='income',"));
  expect(snippet,contains('reviewedOriginalSms:body'));
  expect(snippet,isNot(contains('commitConfirmedSms(')));
  expect(snippet,isNot(contains('commitConfirmedManual(')));
  expect(snippet,isNot(contains('WaffraAutoSms.acknowledge([id])')));
 });

 test('M983 edit button opens same known type instead of another picker',(){
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  expect(review,contains("Navigator.pop(dialog,'m983-direct-edit')"));
  expect(review,contains("if(decision=='m983-direct-edit'&&understood&&!sensitive&&mounted)"));
  expect(review,contains("reviewType=expectedIncome?'income':'expense'"));
  expect(review,contains("decision='correct-type'"));
  expect(review,contains("reviewedSender:sender,reviewedIncomeOverride:reviewType=='income'"));
 });

 test('M983 sensitive messages never expose income expense direct editor',(){
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(review,contains('if(sensitive){'));
  expect(review,contains('await _reviewAutoSmsCandidates(targetId:id)'));
  expect(inbox,contains('if(!confidential)Padding('));
  expect(inbox,contains("item['sensitiveOtp']==true"));
  expect(inbox,contains('WaffraBankSmsFactsParser.isVerificationChallenge('));
 });
}

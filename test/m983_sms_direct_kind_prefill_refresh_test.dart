import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show BankParser, waffraM632ClassifySmsQueue;
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M983/#689 synthetic-only: owner selected type is not finance authority.
void main(){
 test('M983 tapped income expense and transfer have distinct bank evidence',(){
  final cases=<(String,WaffraBankOperationKind)>[
   ('تم إيداع راتب 7000 ريال في حسابك',WaffraBankOperationKind.income),
   ('شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم',
     WaffraBankOperationKind.expense),
   ('حوالة صادرة بين حساباتك بمبلغ 140 ريال',WaffraBankOperationKind.transfer),
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

 test('M983 matched custom rules update status before verifying amounts, never post',(){
  const rules=<WaffraSmsLocalRule>[
   WaffraSmsLocalRule(id:'suggest-income',name:'Salary hint',
    kind:'income',income:true,category:'راتب / راتب أساسي',
    keywords:['راتب'],sender:'MyBank',matchAll:false),
   WaffraSmsLocalRule(id:'suggest-expense',name:'Expense hint',
    kind:'expense',income:false,category:'أخرى / مصروف غير مصنف',
    keywords:['مصروف'],sender:'MyBank',matchAll:false),
   WaffraSmsLocalRule(id:'suggest-transfer',name:'Transfer hint',
    kind:'transfer',income:false,category:'',
    keywords:['حوالة'],sender:'MyBank',matchAll:false),
  ];
  final rows=<Map<String,Object?>>[
   {'id':'1','sender':'MyBank','body':'وصل راتب بدون مبلغ'},
   {'id':'2','sender':'MyBank','body':'رسالة مصروف بدون مبلغ'},
   {'id':'3','sender':'MyBank','body':'حوالة خاصة بدون مبلغ'},
  ];
  final result=waffraM632ClassifySmsQueue(<String,Object?>{
   'results':rows,
   'rules':rules.map((r)=>r.toJson()).toList(),
   'categories':<String>[],
   'hashes':<String>[],
  });
  final waiting=(result['waiting'] as List).cast<Map<String,Object?>>();
  expect(waiting,hasLength(3));
  for(var i=0;i<waiting.length;i++){
   final local=waiting[i]['local'] as Map?;
   expect(local,isNotNull,reason:'No money amount is required for a display hint');
   expect(local!['kind'],const <String>['income','expense','transfer'][i]);
   expect(local['suggestedOnly'],isTrue);
  }
  expect(result['excluded'],isEmpty);
  expect(result['committed'],isEmpty);
  final conflict=waffraM632ClassifySmsQueue(<String,Object?>{
   'results':[rows[0]],'categories':<String>[],
   'hashes':<String>[],
   'rules':[
    rules[0].toJson(),
    WaffraSmsLocalRule(id:'opposing',name:'Conflicting expense',
     kind:'expense',income:false,category:'',
     sender:'MyBank',keywords:['راتب'],matchAll:false).toJson(),
   ],
  });
  expect(((conflict['waiting'] as List).single as Map)['local'],isNull,
   reason:'Conflicting stored kinds stay Needs Review');
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
  expect(inbox,contains("WaffraBankOperationKind.transfer=>'transfer'"));
  expect(inbox,contains("'transfer'}.contains(suggestedKind)"));
 });

 test('M983 direct reviewer uses exact owner native ID, never financial inference',(){
  final review=File('lib/waffra_home_sms_confirmation.part.dart').readAsStringSync();
  final start=review.indexOf('Future<void> _m983OpenSmsTypedTemplate({');
  final end=review.indexOf('Future<void> _reviewAutoSmsCandidates(',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final snippet=review.substring(start,end);
  expect(snippet,contains('WaffraAutoSms.pendingById(id)'));
  expect(snippet,contains("row['id']!=id"));
  expect(snippet,contains("if(kind=='transfer'){"));
  expect(snippet,contains('await _reviewSmsAccountTransfer(item:row,facts:facts)'));
  expect(snippet,contains('await openReviewedSmsManualTransfer(id:id,body:body,sender:sender)'));
  expect(snippet,contains('await _m1011SaveReviewedSmsKind('));
  expect(snippet,contains("income:kind=='income'"));
  final correction=review.substring(
   review.indexOf(' Future<void> _m1011SaveReviewedSmsKind('),start);
  expect(correction,contains('await entrySheet(sms:true,initialSms:body,'));
  expect(correction,contains('reviewedIncomeOverride:income'));
  expect(correction,contains('e.sourceType==\'sms\''));
  expect(correction,contains('smsHashes.contains(hash)'));
  expect(correction,contains('await WaffraAutoSms.acknowledgeCommitted([id])'));
  expect(correction,isNot(contains('await entrySheet(manualIncomeOverride:')));
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
  expect(review,contains("sender:sender,income:reviewType=='income'"));
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 test('M462 verified income SMS builds a sender-scoped safe rule, never autoposts',(){
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',sender:'AlRajhiBank',
   kind:'income',category:'مبالغ مستردة / استرجاع مشتريات',
   confidentOnly:true);
  expect(rule,isNotNull);
  expect(rule!.income,isTrue);
  expect(rule.autoPost,isFalse);
  expect(rule.sender,'AlRajhiBank');
  expect(rule.category,'مبالغ مستردة / استرجاع مشتريات');
  expect(rule.keywords,contains('refund'));
  expect(rule.keywords.join(' '),isNot(contains('50.00')));
  expect(WaffraSmsLocalRules.matches(rule,
   'Refund Received\nAmount: SAR 50.00',sender:'AlRajhiBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(rule,
   'Refund Received\nAmount: SAR 50.00',sender:'OtherBank'),isFalse);
 });

 test('M462 generic or pending bank SMS cannot be learned confidently',(){
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase SAR 75.00 TEST FUEL STATION',
   sender:'Bank',kind:'expense',category:'أخرى / مصروف غير مصنف'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase declined SAR 42.50',
   sender:'Bank',kind:'expense',category:'السيارة / بنزين ووقود'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',
   sender:'',kind:'income',category:'مبالغ مستردة / استرجاع مشتريات'),isNull);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Refund Received\nAmount: SAR 50.00',
   sender:'Bank',kind:'expense',category:'مبالغ مستردة / استرجاع مشتريات'),isNull);
 });

 test('M462 safe OTP exclusion records words and sender but never OTP value',(){
  const body='رمز التفعيل الخاص بك هو 482913، لا تشارك الرمز';
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:body,sender:'AlRajhiBank',kind:'excluded',confidentOnly:true);
  expect(rule,isNotNull);
  expect(rule!.resolvedKind,'excluded');
  expect(rule.autoPost,isFalse);
  expect(rule.keywords,contains('رمز التفعيل'));
  expect(rule.toJson().toString(),isNot(contains('482913')));
  expect(WaffraSmsLocalRules.matches(rule,body,sender:'AlRajhiBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(rule,body,sender:'Unrelated'),isFalse);
  expect(WaffraSmsLocalRules.suggestedRule(
   body:'Card Purchase SAR 75.00 رمز التفعيل',
   sender:'AlRajhiBank',kind:'excluded'),isNull);
 });

 test('M462 transfer rules never create an expense',(){
  final rule=WaffraSmsLocalRules.suggestedRule(
   body:'Credit Transfer via Alinma Bank\nAmount: SAR 1900.00',
   sender:'AlinmaBank',kind:'transfer');
  expect(rule,isNotNull);
  expect(rule!.financial,isFalse);
  expect(rule.autoPost,isFalse);
  expect(rule.keywords,isNotEmpty);
 });

 test('M462 groups confirmed bank SMS into reusable class/category patterns',(){
  const first=WaffraSmsLocalRule(
   id:'smart_abc',name:'مطاعم',kind:'expense',income:false,
   keywords:['restaurant'],category:'مطاعم وكافيهات / مطاعم شعبية',
   sender:'AlRajhiBank',matchAll:false);
  const next=WaffraSmsLocalRule(
   id:'smart_xyz',name:'مطاعم',kind:'expense',income:false,
   keywords:['albaik'],category:'مطاعم وكافيهات / مطاعم شعبية',
   sender:'AlRajhiBank',matchAll:false);
  final merged=WaffraSmsLocalRules.upsertLearned(
   existing:[first],candidate:next);
  expect(merged,hasLength(1));
  expect(merged.single.keywords,containsAll(['restaurant','albaik']));
  expect(WaffraSmsLocalRules.matches(merged.single,
   'Card Purchase at Albaik SAR 40',sender:'AlRajhiBank'),isTrue);
  expect(WaffraSmsLocalRules.matches(merged.single,
   'Card Purchase at Albaik SAR 40',sender:'AnotherBank'),isFalse);
  // Repeated review changes nothing, including IDs and durable rule count.
  final again=WaffraSmsLocalRules.upsertLearned(
   existing:merged,candidate:next);
  expect(again,hasLength(1));
  expect(again.single.id,'smart_abc');
 });

 test('M462 never silently broadens an explicitly enabled autoPost rule',(){
  const authorized=WaffraSmsLocalRule(
   id:'smart_verified',name:'Fuel',kind:'expense',income:false,
   keywords:['petromin'],category:'السيارة / بنزين ووقود',
   sender:'AlRajhiBank',autoPost:true,accountId:'account_123',
   accountSuffix:'1234',matchAll:false);
  const newPattern=WaffraSmsLocalRule(
   id:'smart_other',name:'Fuel',kind:'expense',income:false,
   keywords:['fuel'],category:'السيارة / بنزين ووقود',
   sender:'AlRajhiBank',matchAll:false);
  final result=WaffraSmsLocalRules.upsertLearned(
   existing:[authorized],candidate:newPattern);
  expect(result.first.keywords,['petromin']);
  expect(result.first.autoPost,isTrue);
  expect(result.where((r)=>r.autoPost),hasLength(1));
  expect(result.length,2); // New candidate remains review-only.
 });

 test('M462 repeating authorized patterns never creates an extra smart rule',(){
  const approved=WaffraSmsLocalRule(
   id:'smart_authorized',name:'Fuel',kind:'expense',income:false,
   keywords:['petromin'],category:'السيارة / بنزين ووقود',
   sender:'AlRajhiBank',autoPost:true,accountId:'account_123',
   accountSuffix:'1234',matchAll:false);
  const repeated=WaffraSmsLocalRule(
   id:'smart_repeat',name:'Fuel',kind:'expense',income:false,
   keywords:['petromin'],category:'السيارة / بنزين ووقود',
   sender:'AlRajhiBank',matchAll:false);
  final original=<WaffraSmsLocalRule>[approved];
  final result=WaffraSmsLocalRules.upsertLearned(
   existing:original,candidate:repeated);
  expect(identical(result,original),isTrue);
  expect(result,same(original));
  expect(result,hasLength(1));
  expect(result.single.keywords,['petromin']);
 });

 test('M462 conflicting category evidence cannot poison an existing rule',(){
  const saved=WaffraSmsLocalRule(
   id:'smart_old',name:'food',kind:'expense',income:false,
   keywords:['albaik'],category:'مطاعم وكافيهات / مطاعم شعبية',
   sender:'AlRajhiBank',matchAll:false);
  const conflicting=WaffraSmsLocalRule(
   id:'smart_new',name:'other',kind:'expense',income:false,
   keywords:['albaik'],category:'المنزل / أخرى',
   sender:'AlRajhiBank',matchAll:false);
  final after=WaffraSmsLocalRules.upsertLearned(
   existing:[saved],candidate:conflicting);
  expect(after,hasLength(1));
  expect(after.single.category,saved.category);
 });


 test('M462 different confirmed categories share one learned expense bucket',(){
  const first=WaffraSmsLocalRule(
   id:'manual_food',name:'مصروف',kind:'expense',income:false,
   keywords:['panda'],category:'بقالة وتموين / سوبرماركت',
   sender:'',matchAll:false);
  const second=WaffraSmsLocalRule(
   id:'manual_dinner',name:'مصروف',kind:'expense',income:false,
   keywords:['albaik'],category:'مطاعم وكافيهات / مطاعم شعبية',
   sender:'',matchAll:false);
  final merged=WaffraSmsLocalRules.upsertLearned(
   existing:[first],candidate:second);
  expect(merged,hasLength(1));
  expect(merged.single.id,'manual_food');
  expect(merged.single.keywordCategories['panda'],
   'بقالة وتموين / سوبرماركت');
  expect(merged.single.keywordCategories['albaik'],
   'مطاعم وكافيهات / مطاعم شعبية');
  final reopened=WaffraSmsLocalRule.fromJson(
   Map<String,dynamic>.from(merged.single.toJson()));
  final panda=WaffraSmsLocalRules.resolve(
   body:'Card Purchase at Panda',sender:'Bank',
   bankKind:WaffraBankOperationKind.expense,custom:[reopened]);
  final albaik=WaffraSmsLocalRules.resolve(
   body:'Card Purchase at Albaik',sender:'Bank',
   bankKind:WaffraBankOperationKind.expense,custom:[reopened]);
  expect(panda?.category,'بقالة وتموين / سوبرماركت');
  expect(albaik?.category,'مطاعم وكافيهات / مطاعم شعبية');
  expect(WaffraSmsLocalRules.upsertLearned(
   existing:merged,candidate:second),same(merged));
  expect(WaffraSmsLocalRules.resolve(
   body:'Card Purchase at Panda and Albaik',sender:'Bank',
   bankKind:WaffraBankOperationKind.expense,custom:[reopened]),isNull);
 });

 test('M462 transfer and exclusion reuse separate safe sender buckets',(){
  const transferA=WaffraSmsLocalRule(
   id:'smart_transfer',name:'تحويل',kind:'transfer',income:false,
   category:'',sender:'Bank',keywords:['transfer'],matchAll:false);
  const transferB=WaffraSmsLocalRule(
   id:'smart_transfer_next',name:'تحويل',kind:'transfer',income:false,
   category:'',sender:'Bank',keywords:['تحويل وارد'],matchAll:false);
  final transfers=WaffraSmsLocalRules.upsertLearned(
   existing:[transferA],candidate:transferB);
  expect(transfers,hasLength(1));
  expect(transfers.single.keywords,containsAll(['transfer','تحويل وارد']));
  expect(transfers.single.autoPost,isFalse);
  const excluded=WaffraSmsLocalRule(
   id:'smart_excluded',name:'استثناء',kind:'excluded',income:false,
   category:'',sender:'Bank',keywords:['رمز التحقق'],matchAll:false);
  final separate=WaffraSmsLocalRules.upsertLearned(
   existing:transfers,candidate:excluded);
  expect(separate,hasLength(2));
  expect(separate.map((e)=>e.resolvedKind).toSet(),
   containsAll(['transfer','excluded']));
 });

 test('M462 never merges two contradictory categories for the same phrase',(){
  const old=WaffraSmsLocalRule(
   id:'manual_original',name:'مصروف',kind:'expense',income:false,
   category:'بقالة وتموين / سوبرماركت',sender:'',
   keywords:['panda'],matchAll:false);
  const conflicting=WaffraSmsLocalRule(
   id:'manual_conflict',name:'مصروف',kind:'expense',income:false,
   category:'السيارة / بنزين ووقود',sender:'',
   keywords:['panda'],matchAll:false);
  final originals=<WaffraSmsLocalRule>[old];
  final next=WaffraSmsLocalRules.upsertLearned(
   existing:originals,candidate:conflicting);
  expect(next,same(originals));
  expect(next,hasLength(1));
 });

 test('M462 beginner review is prefilled and keeps finance approval separate',(){
  final ui=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(ui,contains('seedCategory'));
  expect(ui,contains('proposed?.name'));
  expect(ui,contains("Key('waffra-sms-any-keyword')"));
  expect(ui,contains("Key('waffra-sms-advanced-rule-edit')"));
  expect(ui,contains('WaffraSmsLocalRules.validate(rule)'));
  expect(home,contains("Key('waffra-sms-understood-action')"));
  // M470 approved final UX: no Teach shortcut in any review.
  expect(home,isNot(contains("Key('waffra-sms-teach-action')")));
  expect(home,isNot(contains("decision=='teach'")));
  expect(home,contains('Future<bool> _learnSafeSmsRule({'));
  expect(home,contains('await store.write(_smsRuleOwnerKey,updated);'));
  final review=home.substring(
   home.indexOf(' Future<void> _reviewAutoSmsCandidates('),
   home.indexOf(' void _receiveSharedSms('));
  expect(review,isNot(contains('await _openSmsRules(')));
  expect(review,contains("decision=='transfer'&&mounted"));
  expect(review,contains('await _reviewSmsAccountTransfer(item:selected,facts:facts);'));
  expect(review,contains('if(learned&&mounted){'));
  expect(ui,contains(r"Key('waffra-sms-rule-bucket-$kind')"));
  expect(home,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
 });
 test('M462 background SMS respects explicit budget choice before auto-save',(){
  // Gate must read the SAME verified finance snapshot as the posting writer.
  // A selected budget is never inferred from a learned category or sender.
  final source=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(source,contains("before.finance.getString('waffra_named_budgets_v1')"));
  expect(source,contains('WaffraNamedBudget.fromJson'));
  expect(source,contains('!b.deleted&&b.budgetActive&&b.budget>0'));
  expect(source,contains('categories.any((c)=>!c.income&&c.budgetActive&&c.budget>0)'));
  expect(source,contains('final needsBudgetChoice=!parsed.income&&('));
  expect(source,contains('if(needsBudgetChoice){'));
  expect(source,contains('await keepForReview(candidate);'));
  expect(source,contains('await binding.authority.commitConfirmedSms('));
  expect(source.indexOf('if(needsBudgetChoice){'),lessThan(
   source.indexOf('await binding.authority.commitConfirmedSms(')));
  expect(source,contains('await WaffraAutoSms.notifyCommitted('));
  expect(source,contains('linkedBudget:false'));
 });

 test('M462 transfers learned from manual entries are review-only',(){
  final rule=WaffraSmsLocalRules.manualTransferPattern();
  expect(rule.resolvedKind,'transfer');
  expect(rule.autoPost,isFalse);
  expect(rule.financial,isFalse);
  expect(rule.keywords,containsAll(['تحويل','transfer']));
  final original=WaffraSmsLocalRules.upsertLearned(
   existing:const [],candidate:rule);
  final repeat=WaffraSmsLocalRules.upsertLearned(
   existing:original,candidate:rule);
  expect(original,hasLength(1));
  expect(repeat,hasLength(1));
  expect(WaffraSmsLocalRules.resolveSpecial(
    body:'Credit Transfer via Alinma Bank',sender:'Bank',
    bankKind:WaffraBankOperationKind.transfer,custom:original)
   ?.resolvedKind,'transfer');
  expect(WaffraSmsLocalRules.resolve(
    body:'Credit Transfer via Alinma Bank',sender:'Bank',
    bankKind:WaffraBankOperationKind.transfer,custom:original),isNull);
 });

 test('M462 SMS transfer uses verified account-to-account route',(){
  final home=File('lib/main.dart').readAsStringSync();
  final form=File('lib/waffra_account_transaction_form.dart')
   .readAsStringSync();
  final manager=File('lib/waffra_accounts_manager_page.dart')
   .readAsStringSync();
  expect(home,contains('Future<void> _reviewSmsAccountTransfer({'));
  expect(home,contains('WaffraAutoSms.transferIdForMessage(id)'));
  expect(home,isNot(contains("requestId:'sms-transfer-'+bankSmsHash(body)")));
  expect(home,contains("fromId:'',toId:''"));
  expect(home,contains('initialSmsTransfer:prefill'));
  expect(home,contains('await api.transfer(id:draft.requestId'));
  expect(home,contains('ack=await WaffraAutoSms.acknowledgeCompletedTransfer([id])'));
  expect(home,isNot(contains('ack=await WaffraAutoSms.acknowledge([id])')));
  // The transfer mode must remain locked for both SMS-prefilled transfers
  // and the user's explicit Transfer action from Home +.
  expect(form,contains('widget.initialSmsTransfer!=null||'));
  expect(form,contains(
   'widget.initialOperation==WaffraAccountOperation.transfer?null:(choice){'));
  expect(form,contains('mode=WaffraAccountOperation.transfer;'));
  expect(manager,contains('widget.onTransferConfirmed?.call(draft)'));
 });

 test('M462 background safely acknowledges verified exclusions',(){
  final worker=File('lib/waffra_auto_sms_autopost.part.dart')
   .readAsStringSync();
  expect(worker,contains("summary['excluded']=0"));
  expect(worker,contains('WaffraSmsLocalRules.resolveSpecial('));
  expect(worker,contains("rule?.resolvedKind=='excluded'"));
  expect(worker,contains('if(actionable.isEmpty)return summary'));
  expect(worker,contains('for(final candidate in actionable.take(25))'));
  expect(worker,contains('WaffraAutoSms.acknowledge([id])'));
 });

 test('M636 transfers cannot silently post through SMS expense editor',(){
  final source=File('lib/main.dart').readAsStringSync();
  final confirmed=source.substring(
   source.indexOf(' Future<void> _m565ConfirmSms({'),
   source.indexOf(' Future<void> _reviewAutoSmsCandidates('));
  expect(confirmed,contains('!facts.canAutoPostAsIncomeExpense'));
  expect(confirmed,contains('(facts.kind==WaffraBankOperationKind.income)!=income'));
  expect(confirmed,contains('original.currency!=\'SAR\''));
  expect(confirmed,contains('userConfirmed:true'));
  expect(source,contains('WaffraSmsLocalRules.resolve('));

 });

}

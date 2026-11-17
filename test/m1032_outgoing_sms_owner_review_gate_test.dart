import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main(){
 test('M1032 saved background transaction retries local learning without replaying finance',(){
  final worker=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  final recovery=worker.split('static Future<int> _reconcileLearningDebt(').last
   .split(' static Future<Map<String,int>> run()async{').first;
  expect(recovery,contains('await binding.authority.load('));
  expect(recovery,contains('WaffraFinanceRoute.widgetRead'));
  expect(recovery,contains('await store.recordConfirmedFinanceLearning('));
  expect(recovery,isNot(contains('commitConfirmedSms(')));
  expect(recovery,isNot(contains('acknowledgeCommitted(')));
  expect(worker,contains('await _rememberLearningDebt(owner,entry.id);'));
  expect(worker,contains("summary['learningRecovered']=await _reconcileLearningDebt(owner,prefs);"));
 });

 test('M1032 financial edit removes only stale single-owner learned phrase',(){
  final prior=WaffraSmsLocalRules.manualCategoryPattern(
   description:'ستاربكس',category:'مقاهي',income:false)!;
  final revised=WaffraSmsLocalRules.manualCategoryPattern(
   description:'ستاربكس',category:'مطاعم',income:false)!;
  final removed=WaffraSmsLocalRules.reconcileConfirmedManualCorrection(
   existing:[prior],oldCandidate:prior,newCandidate:revised,
   previousStillUsed:false);
  expect(removed,hasLength(1));
  expect(removed.single.category,'مطاعم');
  expect(removed.single.autoPost,isFalse);
  final retained=WaffraSmsLocalRules.reconcileConfirmedManualCorrection(
   existing:[prior],oldCandidate:prior,newCandidate:revised,
   previousStillUsed:true);
  expect(retained.single.category,'مقاهي');
  expect(retained.single.autoPost,isFalse);
 });
 test('M1032 source-verified edit invokes learning correction after finance commit',(){
  final edit=File('lib/waffra_home_entry_sheet.part.dart').readAsStringSync();
  final rule=File('lib/waffra_home_sms_rules.part.dart').readAsStringSync();
  expect(edit,contains('if(!await _m953SaveExistingVerifiedEntry(initial,result,'));
  expect(edit,contains('await _m1032ReconcileEditedFinanceLearning(initial,result)'));
  expect(rule,contains('reconcileConfirmedCategoryCorrection('));
 });

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
 test('M1032 excluded labels cannot expire from a forward wall clock or a reboot',(){
  final native=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  final prune=native.split(
   'private fun pruneExcludedLabelsLocked(context: Context, force: Boolean) {'
  ).last.split('/** Shows only excluded SMS identities').first;
  expect(native,contains('Settings.Global.BOOT_COUNT'));
  expect(native,contains('SystemClock.elapsedRealtime()'));
  expect(prune,contains('if (boot < 0)'));
  expect(prune,contains('witnessedBoot != boot'));
  expect(prune,contains('elapsed - witnessedElapsed < excludedLabelRetentionMs'));
  expect(prune,isNot(contains('now - excludedAt < excludedLabelRetentionMs')));
  expect(prune,contains('active.add(record)'));
  expect(native.split('stampExcludedRetention(context, it)').length-1,3);
  // The owner-scoped fingerprint denial list is retained independently.
  expect(native,contains('private const val excludedMessageBucketPrefix'));
 });

 test('M1032 repeat learned safe rule never consumes capacity or enables AutoPost',(){
  const candidate=WaffraSmsLocalRule(
   id:'smart_repeat_verified',name:'Repeated merchant',
   keywords:['coffeeshop'],kind:'expense',income:false,
   category:'مقاهي',sender:'AlRajhi',matchAll:true,autoPost:false);
  final once=WaffraSmsLocalRules.upsertLearned(
   existing:const [],candidate:candidate);
  final repeated=WaffraSmsLocalRules.upsertLearned(
   existing:once,candidate:candidate);
  expect(repeated.length,1);
  expect(repeated.single.autoPost,isFalse);
  expect(repeated.single.id,'smart_repeat_verified');
 });

 test('M1032 learned buckets spill after 12 keywords without losing approved patterns',(){
  WaffraSmsLocalRule candidate(int i,String category){
   final x=String.fromCharCode(97+(i%26));
   final y=String.fromCharCode(97+((i~/26)%26));
   final word='merchant$x$y';
   return WaffraSmsLocalRule(
    id:'manual_$word',name:'Merchant $x$y',
    keywords:[word],kind:'expense',income:false,
    category:category,sender:'',matchAll:false,autoPost:false,
   );
  }
  var rules=<WaffraSmsLocalRule>[];
  for(var i=0;i<35;i++){
   rules=WaffraSmsLocalRules.upsertLearned(
    existing:rules,candidate:candidate(i,'مقاهي'));
  }
  expect(rules.length,greaterThan(1));
  expect(rules.every((r)=>r.keywords.length<=12&&!r.autoPost),isTrue);
  for(var i=0;i<35;i++){
   final word=candidate(i,'مقاهي').keywords.single;
   expect(rules.any((r)=>r.keywords.contains(word)),isTrue,
    reason:'Learned keyword $word must not be silently discarded');
  }
  final conflict=WaffraSmsLocalRules.upsertLearned(
   existing:rules,candidate:candidate(0,'مطاعم'));
  expect(conflict.length,rules.length);
  expect(conflict.expand((r)=>r.keywords).length,
   rules.expand((r)=>r.keywords).length);
 });

 test('M1032 101 legacy-format rules remain portable; oversized archive is refused',(){
  final rows=<WaffraSmsLocalRule>[
   for(var i=0;i<101;i++)
    WaffraSmsLocalRule(id:'custom_local_$i',name:'Merchant pattern',
     kind:'expense',income:false,category:'مقاهي',
     keywords:['coffeeshop'],sender:'',matchAll:false,autoPost:false),
  ];
  const owner='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  Object archive(List<WaffraSmsLocalRule> rules)=><String,Object?>{
   'version':1,'owner':owner,
   'rules':[for(final rule in rules)rule.toJson()],
  };
  final restored=WaffraSmsLocalRuleStore.validatePortableBackup(archive(rows));
  expect((restored['rules'] as List).length,101);
  final old=WaffraSmsLocalRuleStore.validatePortableBackup(
    archive(rows.take(100).toList()));
  expect((old['rules'] as List).length,100);
  expect(()=>WaffraSmsLocalRuleStore.validatePortableBackup(
   archive(List<WaffraSmsLocalRule>.filled(
    WaffraSmsLocalRules.maxStoredRules+1,rows.first))),
    throwsFormatException);
 });

 test('M1032 Delete All uses recoverable archive and retains SMS anti-replay',(){
  final bridge=File('lib/storage/waffra_verified_encrypted_finance_bridge.dart')
   .readAsStringSync();
  final authority=File('lib/storage/waffra_verified_finance_authority.dart')
   .readAsStringSync();
  final ui=File('lib/waffra_home_delete_all_transactions.part.dart')
   .readAsStringSync();
  final recycle=File('lib/storage/waffra_encrypted_transaction_recycle.dart')
   .readAsStringSync();
  expect(bridge,contains('.recycleAll('));
  expect(authority,contains(
   "witness.snapshot.values['waffra_sms_hashes_v1'] ?? const <String>[]"));
  expect(ui,contains('المحذوفات المشفرة لمدة 30 يومًا'));
  expect(ui,isNot(contains('smsHashes.clear();')));
  expect(recycle,contains('Future<WaffraFinanceSnapshotState> recycleAll('));
  expect(recycle,contains('await _requireExactTypedLedger(ledger);'));
  expect(recycle,contains('await vault.readAll(entryId)'));
  expect(recycle,contains('INSERT INTO $_accountLinks'));
  expect(recycle,contains('INSERT INTO $_images'));
  expect(recycle,isNot(contains("..['waffra_sms_hashes_v1'] = <String>[]")));
 });

 test('M1032 rule UI exposes bounded capacity without silently changing older rules',(){
  final ui=File('lib/waffra_sms_rule_settings_page.dart').readAsStringSync();
  expect(ui,contains("Key('m1032-rule-capacity-count')"));
  expect(ui,contains('saved.length>=WaffraSmsLocalRules.maxStoredRules'));
  expect(WaffraSmsLocalRules.maxStoredRules,256);
 });

}

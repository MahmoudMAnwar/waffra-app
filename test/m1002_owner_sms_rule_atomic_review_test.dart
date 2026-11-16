import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 String src(String file)=>File(file).readAsStringSync();
 test('M1002 all app SMS rule mutations serialize by verified owner',(){
  final store=src('lib/waffra_sms_local_rules.dart');
  expect(store,contains('static final Map<String,Future<void>> _writeTail={}'));
  expect(store,contains('Future<T> _exclusive<T>('));
  expect(store,contains('Future<void> writeIfCurrent('));
  expect(store,contains('Future<WaffraSmsRuleLearningResult> learnReviewedCandidates('));
  expect(store,contains(')=>_exclusive(owner,()async{'));
  expect(store,contains('final current=await read(owner);'));
  expect(store,contains('if(changed)await _writeUnlocked(owner,next);'));
  expect(store,contains('final verified=await read(owner);'));
  expect(store,contains('Saved SMS rules differ from the requested patterns.'));
  expect(store,contains('SMS rules changed in another review. Reload first.'));
 });
 test('M1002 safe learning persists only after user confirmation',(){
  final home=src('lib/waffra_home_sms_rules.part.dart');
  final bulk=src('lib/waffra_home_sms_management.part.dart');
  expect(home,contains('await store.learnReviewedCandidates('));
  expect(home,contains('if(saved.changed)_receiveAutoSmsNotice();'));
  expect(home,contains('final latest=await store.read(_smsRuleOwnerKey);'));
  expect(bulk,contains('learnReviewedCandidates(_smsRuleOwnerKey,candidates)'));
  expect(bulk,contains('done.length!=selected.length'));
  expect(bulk,contains('ruleWarning'));
  expect(home,isNot(contains('commitConfirmedSms(')));
 });
 test('M1002 safe pattern upsert never duplicates learned excluded rule',(){
  final rule=WaffraSmsLocalRule(
   id:'owner-safe-exclusion-a',
   name:'Synthetic exclusion',sender:'SafeNotify',kind:'excluded',
   income:false,category:'',keywords:const ['verification'],
   matchAll:false,
  );
  WaffraSmsLocalRules.validate(rule);
  final first=WaffraSmsLocalRules.upsertLearned(
   existing:const <WaffraSmsLocalRule>[],candidate:rule);
  final second=WaffraSmsLocalRules.upsertLearned(
   existing:first,candidate:rule);
  expect(first,hasLength(1));
  expect(second,hasLength(1));
  expect(WaffraSmsLocalRules.matches(second.single,
   'verification message',sender:'SafeNotify'),isTrue);
 });
}

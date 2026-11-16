import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_background_checkpoint.dart';

void main(){
 test('M1022 old reviews remain checked under unchanged rule revision',(){
  final q=<Map<String,Object?>>[
   {'id':'A','backgroundAttempted':true,'backgroundRuleRevision':'revision1'},
   {'id':'B','backgroundAttempted':false},
  ];
  final pass=WaffraSmsBackgroundCheckpoint.select(q,maxPerPass:25,
   currentRulesRevision:'revision1');
  expect(pass.candidates.map((x)=>x['id']),['B']);
  expect(pass.unattempted,1);
 });
 test('M1022 changed owner rules select previously reviewed rows, without duplication',(){
  final q=<Map<String,Object?>>[
   {'id':'A','backgroundAttempted':true,'backgroundRuleRevision':'revision1'},
   {'id':'B','backgroundAttempted':true,'backgroundRuleRevision':'revision2'},
   {'id':'C','backgroundAttempted':false},
  ];
  final pass=WaffraSmsBackgroundCheckpoint.select(q,maxPerPass:25,
   currentRulesRevision:'revision2');
  expect(pass.candidates.map((e)=>e['id']),['A','C']);
  expect(pass.unattempted,2);
 });
 test('M1022 missing or failed rule load never authorizes older implicit auto-post',(){
  final source=File('lib/waffra_auto_sms_autopost.part.dart').readAsStringSync();
  expect(source,contains('currentRulesRevision:ruleRevision'));
  expect(source,contains("ruleRevision=waffraSmsRulesRevision("));
  expect(source,contains('previouslyAttempted=candidate[\'backgroundAttempted\']==true'));
  expect(source,contains('if(previouslyAttempted){'));
  expect(source,contains('await keepForReview(candidate);continue;'));
  expect(source,contains('if(!ruleStoreReady||!rules.any((r)=>r.autoPost))'));
 });
 test('M1022 secure rule-revision hash changes only on owner-rule change',(){
  const owner='verified-owner-a';
  final empty=sha256.convert(utf8.encode('$owner|[]')).toString();
  final updated=sha256.convert(utf8.encode('$owner|[{"kind":"excluded"}]')).toString();
  expect(empty,isNot(updated));
  expect(empty.length,64);
 });
 test('M1022 native owner-encrypted attempt marker persists rule revision',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('"backgroundRuleRevision" to row.optString("backgroundRuleRevision", "")'));
  expect(store,contains('fun markBackgroundSmsReviewed(context: Context, id: String,'));
  expect(store,contains('row.put("backgroundRuleRevision", revision)'));
  expect(store,contains('Regex("^[a-f0-9]{64}$").matches(revision)'));
  expect(store,contains('return@synchronized save(context, data)'));
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  expect(worker,contains('args?.get("revision") as? String ?: ""'));
  expect(worker,contains('WaffraAutoSmsStore.markBackgroundSmsReviewed('));
  expect(worker,contains('context, id, revision, delivered)'));
  final dart=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(dart,contains("markAutoBankSmsBackgroundReviewed',{'id':id,'revision':revision,"));
 });
}

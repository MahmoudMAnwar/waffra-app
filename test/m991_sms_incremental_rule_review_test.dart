import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show waffraM632ClassifySmsQueue;
import 'package:waffra/waffra_sms_incremental_rule_review.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const salary=WaffraSmsLocalRule(
  id:'salary',name:'Salary',sender:'BANK',keywords:['راتب'],
  kind:'income',income:true,category:'راتب / راتب أساسي');
 const expense=WaffraSmsLocalRule(
  id:'expense',name:'Shop',sender:'BANK',keywords:['متجر'],
  kind:'expense',income:false,category:'بقالة وتموين / سوبرماركت');

 Map<String,Object?> row(String id,String body,{String sender='BANK'})=>
  <String,Object?>{
   'id':id.padRight(64,'a'),'sender':sender,'body':body,
   'receivedAt':DateTime.utc(2026,11,15).millisecondsSinceEpoch,
  };
 Map<String,Object?> classify(List<Map<String,Object?>> rows,{
  List<WaffraSmsLocalRule> rules=const [],
  List<WaffraSmsLocalRule> previousRules=const [],
  List<Map<String,Object?>> cached=const [],
 })=>waffraM632ClassifySmsQueue(<String,Object?>{
  'results':rows,'rules':rules.map((r)=>r.toJson()).toList(),
  'previousRules':previousRules.map((r)=>r.toJson()).toList(),
  'cached':cached,
  'hashes':<String>[],'categories':<String>[],
 });
 List<Map<String,Object?>> cached(Map<String,Object?> first)=>[
  for(final row in (first['waiting'] as List).cast<Map<String,Object?>>())
   <String,Object?>{
    'id':row['id'],'sender':row['sender'],
    'm991SourceHash':row['m991SourceHash'],
    'm991Evaluated':row['m991Evaluated'],
    if(row['local'] is Map)'local':row['local'],
   },
 ];

 test('M991 unchanged current native SMS avoids repeating four-kind matching',(){
  final rows=[
   row('1','عملية غير معروفة'),
   row('2','تم إيداع راتب 7000 SAR'),
  ];
  final prior=classify(rows,rules:const [salary]);
  final second=classify(rows,rules:const [salary],
    previousRules:const [salary],cached:cached(prior));
  expect(prior['cacheHits'],0);
  expect(second['cacheHits'],2);
  expect((second['waiting'] as List).length,2);
  expect(second['excluded'],isEmpty);
  expect(second['committed'],isEmpty);
 });

 test('M991 changed keyword reclassifies matching SMS only',(){
  final rows=[
   row('1','عملية غير معروفة'),
   row('2','شراء من متجر بقيمة 50 ريال'),
  ];
  final first=classify(rows,rules:const [salary]);
  final second=classify(rows,
   rules:const [salary,expense],
   previousRules:const [salary],cached:cached(first));
  expect(second['cacheHits'],1);
  expect((second['waiting'] as List).length,2);
  final changed=WaffraSmsIncrementalRuleReview.changedRules(
   const [salary],const [salary,expense]);
  expect(changed.map((r)=>r.id).toSet(),{'expense'});
  expect(WaffraSmsIncrementalRuleReview.affected(
    body:'شراء من متجر بقيمة 50 ريال',sender:'BANK',changes:changed),isTrue);
  expect(WaffraSmsIncrementalRuleReview.affected(
    body:'عملية غير معروفة',sender:'BANK',changes:changed),isFalse);
 });

 test('M991 removed, edited and differently scoped rules cannot inherit status',(){
  const newSalary=WaffraSmsLocalRule(
   id:'salary',name:'Other',sender:'OTHER',keywords:['راتب'],
   kind:'income',income:true,category:'راتب / راتب أساسي');
  final changed=WaffraSmsIncrementalRuleReview.changedRules(
   const [salary],const [newSalary]);
  expect(changed.length,2);
  expect(WaffraSmsIncrementalRuleReview.affected(
   body:'راتب 800 SAR',sender:'BANK',changes:changed),isTrue);
  expect(WaffraSmsIncrementalRuleReview.affected(
   body:'راتب 800 SAR',sender:'OTHER',changes:changed),isTrue);
 });

 test('M991 only exact sender, hash and native id can reuse',(){
  const body='Bank transaction pending review';
  const valid=<String,Object?>{
   'id':'native-1','sender':'BANK','m991SourceHash':'trusted-hash',
   'm991Evaluated':true,
  };
  bool reuse(Map<String,Object?> old,{String id='native-1',
      String sender='BANK',String hash='trusted-hash'})=>
    WaffraSmsIncrementalRuleReview.canReuse(
     previous:old,currentId:id,currentSender:sender,
     currentBodyHash:hash,currentBody:body,changed:const []);
  expect(reuse(valid),isTrue);
  expect(reuse(valid,id:'native-2'),isFalse);
  expect(reuse(valid,sender:'OTHER'),isFalse);
  expect(reuse(valid,hash:'changed-hash'),isFalse);
  expect(reuse({...valid,'local':{'kind':'excluded'}}),isFalse);
  expect(reuse({...valid,'m991Evaluated':false}),isFalse);
 });

 test('M991 removed native pending ID cannot be resurrected by cached rows',(){
  final previous=classify([row('old','لا يوجد شيء')]);
  final next=classify([row('new','لا يوجد شيء')],
    cached:cached(previous));
  expect(next['cacheHits'],0);
  final actual=(next['waiting'] as List).cast<Map<String,Object?>>();
  expect(actual.map((e)=>e['id']),[row('new','')['id']]);
 });
}

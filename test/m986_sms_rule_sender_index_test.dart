import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 const rules=<WaffraSmsLocalRule>[
  WaffraSmsLocalRule(id:'a',name:'global',keywords:['شراء'],
   income:false,category:'مشتريات',kind:'expense',sender:''),
  WaffraSmsLocalRule(id:'b',name:'bank',keywords:['شراء'],
   income:false,category:'مشتريات',kind:'expense',sender:'MyBank'),
  WaffraSmsLocalRule(id:'c',name:'other',keywords:['شراء'],
   income:false,category:'مشتريات',kind:'expense',sender:'OtherBank'),
  WaffraSmsLocalRule(id:'d',name:'exclude',keywords:['شراء'],
   income:false,category:'',kind:'excluded',sender:'MyBank'),
  WaffraSmsLocalRule(id:'e',name:'multi',keywords:['تم','شراء'],
   income:false,category:'مشتريات',kind:'expense',sender:'MyBank',
   matchAll:true),
 ];
 test('M986 indexed versus full scanner preserve four-kind matches and order',(){
  final index=WaffraSmsRuleCandidateIndex(rules);
  for(final sender in ['MyBank','OtherBank','UNKNOWN',' mybank ']){
   for(final body in ['تم شراء بقيمة 50 ريال',
      'تم تنشيط المستفيد: أحمد','OTP 445566',
      'شراء من MY STORE','salary credited 100 SAR',
      'عملية غير معروفة']){
    final baseline=WaffraSmsLocalRules.matchAllFourKinds(
     body:body,sender:sender,custom:rules);
    final indexed=WaffraSmsLocalRules.matchAllFourKinds(
     body:body,sender:sender,custom:rules,candidateIndex:index);
    expect(indexed.map((r)=>r.id).toList(),
     baseline.map((r)=>r.id).toList(),
     reason:'Unchanged rule precedence, sender and safety for $sender');
   }
  }
 });
 test('M986 sender and 2-character keyword prefix prune unrelated rules',(){
  final index=WaffraSmsRuleCandidateIndex(rules);
  expect(index.candidates(sender:'MyBank',body:'تم شراء')
   .map((e)=>e.id).toSet().containsAll(['a','b','d','e']),isTrue);
  expect(index.candidates(sender:'OtherBank',body:'تم شراء')
   .map((e)=>e.id).contains('b'),isFalse);
  expect(index.candidates(sender:'MyBank',body:'تم شراء')
   .map((e)=>e.id).contains('c'),isFalse);
  expect(index.candidates(sender:'MyBank',body:'راتب')
   .map((e)=>e.id).contains('a'),isFalse);
 });
 test('M986 real messages repeated with cached index retain no false negatives',(){
  final index=WaffraSmsRuleCandidateIndex(rules);
  for(var n=0;n<100;n++){
   final body=n.isEven?'شراء 50 ريال':'حوالة واردة 500 ريال';
   final indexed=WaffraSmsLocalRules.matchAllFourKinds(
    body:body,sender:'MyBank',custom:rules,candidateIndex:index);
   final full=WaffraSmsLocalRules.matchAllFourKinds(
    body:body,sender:'MyBank',custom:rules);
   expect(indexed.map((e)=>e.id).toList(),full.map((e)=>e.id).toList());
  }
 });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 test('M986 sender index preserves all four-way matches and rule ordering',(){
  const rules=<WaffraSmsLocalRule>[
   WaffraSmsLocalRule(id:'a',name:'global',keywords:['شراء'],
    income:false,category:'مشتريات',kind:'expense',sender:''),
   WaffraSmsLocalRule(id:'b',name:'bank',keywords:['شراء'],
    income:false,category:'مشتريات',kind:'expense',sender:'MyBank'),
   WaffraSmsLocalRule(id:'c',name:'other',keywords:['شراء'],
    income:false,category:'مشتريات',kind:'expense',sender:'OtherBank'),
   WaffraSmsLocalRule(id:'d',name:'exclude',keywords:['شراء'],
    income:false,category:'',kind:'excluded',sender:'MyBank'),
  ];
  final index=WaffraSmsRuleSenderIndex(rules);
  for(final sender in ['MyBank','OtherBank','UNKNOWN',' mybank ']){
   const body='شراء بقيمة 50 ريال';
   final baseline=WaffraSmsLocalRules.matchAllFourKinds(
    body:body,sender:sender,custom:rules);
   final indexed=WaffraSmsLocalRules.matchAllFourKinds(
    body:body,sender:sender,custom:index.candidates(sender));
   expect(indexed.map((r)=>r.id).toSet(),baseline.map((r)=>r.id).toSet(),
    reason:'No rule match can be lost for sender $sender');
  }
 });
 test('M986 sender candidates cannot match unrelated owner bank',(){
  const rules=<WaffraSmsLocalRule>[
   WaffraSmsLocalRule(id:'one',name:'one',keywords:['شراء'],
    income:false,category:'',sender:'Bank1'),
   WaffraSmsLocalRule(id:'two',name:'two',keywords:['شراء'],
    income:false,category:'',sender:'Bank2'),
  ];
  final index=WaffraSmsRuleSenderIndex(rules);
  expect(index.candidates('Bank1').map((e)=>e.id),['one']);
  expect(index.candidates('Bank2').map((e)=>e.id),['two']);
  expect(index.candidates('Bank3'),isEmpty);
 });
}

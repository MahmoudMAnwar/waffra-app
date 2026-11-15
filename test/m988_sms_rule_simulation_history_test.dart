import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_rule_simulator.dart';

void main(){
 test('M988 revision stack bounded to five encrypted snapshots',(){
  final snapshots=WaffraSmsLocalRuleStore.boundedHistory(
   ['v1','v2','v3','v4','v5'],'v6');
  expect(snapshots,['v2','v3','v4','v5','v6']);
 });
 test('M988 simulation is read-only and detects impact and conflicts',(){
  const saved=<WaffraSmsLocalRule>[
   WaffraSmsLocalRule(id:'rent',name:'rent',keywords:['ايجار'],
    income:false,kind:'expense',category:'سكن',sender:'Bank'),
  ];
  const preview=WaffraSmsLocalRule(
   id:'new',name:'transfer',keywords:['ايجار'],
   income:false,kind:'transfer',category:'',sender:'Bank');
  final before=List<WaffraSmsLocalRule>.of(saved);
  final result=WaffraSmsRuleSimulator.compare(
   existing:saved,preview:preview,
   samples:const [
    MapEntry('Bank','تم خصم ايجار 1500 ريال'),
    MapEntry('Other','تم خصم ايجار 100 ريال'),
   ]);
  expect(result.examined,2);
  expect(result.changed,1);
  expect(result.conflicts,1);
  expect(saved.map((r)=>r.id).toList(),before.map((r)=>r.id).toList());
 });
 test('M988 preview does not match another sender',(){
  const preview=WaffraSmsLocalRule(
   id:'new',name:'salary',keywords:['salary'],
   income:true,kind:'income',category:'راتب',sender:'Bank1');
  final result=WaffraSmsRuleSimulator.compare(
   existing:const [],preview:preview,
   samples:const [MapEntry('Bank2','salary credited')]);
  expect(result.changed,0);
 });
}

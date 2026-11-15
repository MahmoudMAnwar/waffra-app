import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_rule_simulator.dart';

void main(){
  test('M990 a matching purchase cannot be excluded only by keywords',(){
    const preview=WaffraSmsLocalRule(
      id:'proposed_exclusion',name:'Unsafe keyword',
      keywords:['purchase'],kind:'excluded',income:false,
      category:'',sender:'AlRajhi');
    const sample=<MapEntry<String,String>>[
      MapEntry('AlRajhi','Purchase Card 100 SAR\nAccount: **1234'),
      MapEntry('Other','Purchase Card 50 SAR\nAccount: **5678'),
    ];
    final impact=WaffraSmsRuleSimulator.compare(
      existing:const [],preview:preview,samples:sample);
    expect(impact.examined,2);
    expect(impact.changed,1);
    expect(impact.blockedExclusions,1);
  });

  test('M990 safe standalone OTP does not count as blocked finance',(){
    const preview=WaffraSmsLocalRule(
      id:'otp_rule',name:'OTP',
      keywords:['OTP'],kind:'excluded',income:false,
      category:'',sender:'AlRajhi');
    final impact=WaffraSmsRuleSimulator.compare(
      existing:const [],preview:preview,
      samples:const [MapEntry('AlRajhi','OTP 445566')]);
    expect(impact.examined,1);
    expect(impact.blockedExclusions,0);
  });

  test('M990 mixed OTP and completed finance cannot be silently excluded',(){
    const preview=WaffraSmsLocalRule(
      id:'otp_rule',name:'OTP',keywords:['OTP'],
      kind:'excluded',income:false,category:'',sender:'AlRajhi');
    final impact=WaffraSmsRuleSimulator.compare(
      existing:const [],preview:preview,
      samples:const [MapEntry('AlRajhi',
        'Purchase Card 100 SAR\nOTP 445566\nAccount: **1234')]);
    expect(impact.blockedExclusions,1);
  });
}

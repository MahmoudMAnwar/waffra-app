import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';
import 'package:waffra/waffra_sms_saudi_template_registry.dart';

void main(){
 const rules=<WaffraSmsLocalRule>[
  WaffraSmsLocalRule(id:'a',name:'Salary',sender:'AlRajhi',
   keywords:['راتب'],kind:'income',income:true,category:'راتب / راتب أساسي'),
  WaffraSmsLocalRule(id:'b',name:'Merchant',sender:'AlRajhi',
   keywords:['العثيم'],kind:'expense',income:false,
   category:'بقالة وتموين / سوبرماركت'),
  WaffraSmsLocalRule(id:'c',name:'Transfer',sender:'AlRajhi',
   keywords:['حوالة صادرة'],kind:'transfer',income:false,category:''),
  WaffraSmsLocalRule(id:'d',name:'Challenge',sender:'AlRajhi',
   keywords:['رمز التحقق'],kind:'excluded',income:false,category:''),
 ];
 const corpus=<String>[
  'شراء لدى العثيم بمبلغ 22 SAR\nAccount: **1234',
  'Salary Deposit 7000 SAR\nRef: ABC12345',
  'حوالة صادرة 50 ريال\nAccount: **1234',
  'رمز التحقق ١٢٣٤٥٦',
  'Pending Purchase Card 30 SAR\nRef: ZYX12345',
  'Purchase Card\nAmount 20 USD\nAccount: **1234',
  'Purchase Card 10 SAR\nFee: 1 SAR\nVAT: 0.15 SAR',
  'Beneficiary Added: Ahmed',
  'Refund Received 5 SAR\nRef: REF12345',
  'Cashback Received 2 SAR',
 ];
 final index=WaffraSmsRuleCandidateIndex(rules);
 for(final count in const [100,1000,2000]){
  test('M998 deterministic '+count.toString()+' bank SMS index parity',(){
   final watch=Stopwatch()..start();
   var classified=0,unsafe=0,recognized=0;
   for(var i=0;i<count;i++){
    final text=corpus[i%corpus.length];
    final sender=i%5==0?'OtherSender':'AlRajhi';
    final full=WaffraSmsLocalRules.matchAllFourKinds(
     body:text,sender:sender,custom:rules);
    final fast=WaffraSmsLocalRules.matchAllFourKinds(
     body:text,sender:sender,custom:rules,candidateIndex:index);
    expect(fast.map((x)=>x.id).toList(),full.map((x)=>x.id).toList());
    final ctx=WaffraSmsStructuredBankContext.parse(text,sender:sender);
    if(ctx.principalSar==null)unsafe++;
    if(ctx.templateFamily!=null)recognized++;
    if(ctx.facts.securityChallenge){
     expect(ctx.principalSar,isNull);
     expect(ctx.accountLastFour,isNull);
    }
    if(ctx.sourceCurrencies.any((x)=>x!='SAR')){
     expect(ctx.principalSar,isNull);
    }
    classified++;
   }
   watch.stop();
   // Telemetry on CI only, not fake Android frame measurement.
   // ignore: avoid_print
   print('WAFFRA_SMS_M998 rows='+count.toString()+
     ' ms='+watch.elapsedMilliseconds.toString()+
     ' needs_review='+unsafe.toString()+
     ' template_matches='+recognized.toString());
   expect(classified,count);
   expect(unsafe,greaterThan(0));
   expect(recognized,greaterThan(0));
  });
 }

 test('M998 unknown sender never becomes verified bank template',(){
  const text='Purchase Card 40 SAR\nAccount **1234';
  final ctx=WaffraSmsStructuredBankContext.parse(text,sender:'RandomApp');
  expect(ctx.templateFamily,isNull);
  expect(ctx.accountLastFour,isNull);
  expect(WaffraSaudiSmsTemplateRegistry.identify(
   providerId:'RandomApp',body:text),isNull);
 });
}

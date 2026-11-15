import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_lifecycle_evidence.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main() {
  test('M990 pending quote is retained solely for read-only relation key', () {
    const pendingText =
      'Pending Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345';
    const postedText =
      'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345';
    final pending = WaffraSmsStructuredBankContext.parse(
      pendingText, sender:'AlRajhi');
    final posted = WaffraSmsStructuredBankContext.parse(
      postedText, sender:'AlRajhi');
    expect(pending.pending, isTrue);
    expect(pending.principalSar, isNull);
    expect(pending.referenceAmountSar, 100);
    expect(posted.referenceAmountSar, 100);
    expect(posted.principalSar, 100);
    final index = WaffraSmsRelatedEventIndex();
    final first = WaffraSmsLifecycleEvidence.inspect(
      pendingText, sender:'AlRajhi', context:pending);
    final second = WaffraSmsLifecycleEvidence.inspect(
      postedText, sender:'AlRajhi', context:posted);
    expect(index.inspectAndRemember(first), WaffraSmsRelatedEvent.none);
    expect(index.inspectAndRemember(second),
      WaffraSmsRelatedEvent.possibleSettlement);
  });

  test('M990 foreign and ambiguous amount cannot provide SAR relation key', () {
    const foreign =
      'Purchase Card 20 USD\nAccount: **1234\nRef: ABC12345';
    final context = WaffraSmsStructuredBankContext.parse(
      foreign, sender:'AlRajhi');
    expect(context.referenceAmountSar, isNull);
    expect(context.principalSar, isNull);
    final event = WaffraSmsLifecycleEvidence.inspect(
      foreign, sender:'AlRajhi', context:context);
    expect(event.relationKey, isNull);
    expect(event.stage, WaffraSmsLifecycleStage.uncertain);
  });

  test('M990 unrelated account or amount never joins same bank reference', () {
    WaffraSmsLifecycleEvidence parse(String amount,String ending) {
      final sms='Purchase Card $amount SAR\nAccount: **$ending\nRef: ABC12345';
      final context=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
      return WaffraSmsLifecycleEvidence.inspect(
        sms,sender:'AlRajhi',context:context);
    }
    final index = WaffraSmsRelatedEventIndex();
    expect(index.inspectAndRemember(parse('100','1234')),
      WaffraSmsRelatedEvent.none);
    expect(index.inspectAndRemember(parse('110','1234')),
      WaffraSmsRelatedEvent.none);
    expect(index.inspectAndRemember(parse('100','5678')),
      WaffraSmsRelatedEvent.none);
    expect(index.inspectAndRemember(parse('100','1234')),
      WaffraSmsRelatedEvent.possibleDuplicate);
  });

  test('M990 no 1000-message false positive across unique bank references', () {
    final index = WaffraSmsRelatedEventIndex();
    for(var i=0;i<1000;i++){
      final sms='Purchase Card 20 SAR\nAccount: **1234\nRef: REF${200000+i}';
      final context=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
      final item=WaffraSmsLifecycleEvidence.inspect(
        sms,sender:'AlRajhi',context:context);
      expect(index.inspectAndRemember(item),WaffraSmsRelatedEvent.none);
    }
  });

  test('M990 100/1000/2000 rule-index parity and measurable timings', () {
    const rules = <WaffraSmsLocalRule>[
      WaffraSmsLocalRule(id:'buy',name:'buy',keywords:['شراء'],
        income:false,kind:'expense',category:'مشتريات',sender:'AlRajhi'),
      WaffraSmsLocalRule(id:'salary',name:'salary',keywords:['راتب'],
        income:true,kind:'income',category:'راتب',sender:'SNB'),
      WaffraSmsLocalRule(id:'otp',name:'otp',keywords:['رمز التحقق'],
        income:false,kind:'excluded',category:'',sender:''),
      WaffraSmsLocalRule(id:'transfer',name:'transfer',keywords:['حوالة'],
        income:false,kind:'transfer',category:'',sender:''),
    ];
    final index=WaffraSmsRuleCandidateIndex(rules);
    const inputs=<({String sender,String body})>[
      (sender:'AlRajhi',body:'شراء 100 ريال من متجر'),
      (sender:'SNB',body:'راتب وارد 5300 SAR'),
      (sender:'UNKNOWN',body:'رمز التحقق OTP 445566'),
      (sender:'AlRajhi',body:'حوالة صادرة 400 ريال'),
      (sender:'SNB',body:'خصم 200 ريال'),
      (sender:'UNKNOWN',body:'لا توجد حركة مالية'),
    ];
    for(final size in const <int>[100,1000,2000]){
      final sample=List.generate(size,(i)=>inputs[i%inputs.length],
        growable:false);
      final plainClock=Stopwatch()..start();
      final plain=<List<String>>[
        for(final item in sample)
          WaffraSmsLocalRules.matchAllFourKinds(
            body:item.body,sender:item.sender,custom:rules)
            .map((e)=>e.id).toList(growable:false),
      ];
      plainClock.stop();
      final indexedClock=Stopwatch()..start();
      for(var i=0;i<sample.length;i++){
        final item=sample[i];
        final result=WaffraSmsLocalRules.matchAllFourKinds(
          body:item.body,sender:item.sender,custom:rules,
          candidateIndex:index);
        expect(result.map((e)=>e.id).toList(),plain[i],
          reason:'Exact four-kind rule parity at item $i of $size');
      }
      indexedClock.stop();
      // CI machine speeds vary; evidence is recorded, not hard-coded
      // into brittle thresholds or used to claim a guaranteed speedup.
      print('M990_SMS_RULE_BENCH count=$size '
        'full_us=${plainClock.elapsedMicroseconds} '
        'indexed_us=${indexedClock.elapsedMicroseconds}');
    }
  });

  test('M990 principal, bank fee and SAR VAT stay distinct read-only fields', () {
    const sms='Purchase Card\nAmount: 120.00 SAR\n'
      'Account: **1234\nFee: 2.00 SAR\nVAT: 0.30 SAR';
    final result=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
    expect(result.principalSar,120.0);
    expect(result.referenceAmountSar,120.0);
    expect(result.feeSar,2.0);
    expect(result.vatSar,0.30);
    // The principal never becomes 122.30 without explicit finance review.
    expect(result.principalSar, isNot(122.30));
  });

  test('M990 Arabic VAT digits/decimal notation only when SAR is explicit', () {
    expect(WaffraSmsStructuredBankContext.quotedVatSar(
      'ضريبة القيمة المضافة: ٢٫٥٠ ريال'),2.5);
    expect(WaffraSmsStructuredBankContext.quotedVatSar(
      'VAT: 2.50 USD'),isNull);
    expect(WaffraSmsStructuredBankContext.quotedVatSar(
      'VAT: 2.50'),isNull);
    expect(WaffraSmsStructuredBankContext.quotedVatSar(
      'VAT: 2.50 SAR\nVAT: 2.50 SAR'),isNull);
    expect(WaffraSmsStructuredBankContext.quotedVatSar(
      'Available balance 500 SAR'),isNull);
  });

  test('M990 twelve Saudi sender aliases keep bank and principal separate', () {
    const providers=<String,String>{
      'AlRajhi':'rajhi',
      'AlInma':'inma',
      'SNB':'snb',
      'Riyad':'riyad',
      'Bilad':'bilad',
      'SABB':'sabb',
      'ANB':'anb',
      'BSF':'bsf',
      'SAIB':'saib',
      'Jazira':'jazira',
      'D360':'d360',
      'Barq':'barq',
    };
    const sms='Purchase Card\nAmount: 85.00 SAR\n'
      'Account: **1234\nRef: ABC12345';
    for(final sender in providers.entries){
      final facts=WaffraSmsStructuredBankContext.parse(
        sms,sender:sender.key);
      expect(facts.providerId,sender.value,reason:sender.key);
      expect(facts.principalSar,85.0,reason:sender.key);
      // Wallet sender recognition is NOT bank account ownership evidence.
      // Only bank/digital-bank owners get a masked suffix proposal.
      expect(facts.accountLastFour,
       sender.value=='barq'?isNull:'1234',reason:sender.key);
    }
  });

  test('M990 VAT after SAR fee does not turn VAT into foreign fee code',(){
    const sms='Purchase Card 100 SAR\nAccount: **1234\n'
      'Fee: 2.00 SAR\nVAT: 0.30 SAR';
    final facts=WaffraBankSmsFactsParser.parse(sms);
    expect(facts.pending,isFalse);
    expect(facts.fee,2.00);
    final preview=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
    expect(preview.principalSar,100.0);
    expect(preview.feeSar,2.00);
    expect(preview.vatSar,0.30);
  });

  test('M990 foreign currency on the same fee field remains blocked',(){
    const sms='Purchase Card 100 SAR\nAccount: **1234\n'
      'Fee: 2.00 USD\nVAT: 0.30 SAR';
    final facts=WaffraBankSmsFactsParser.parse(sms);
    expect(facts.pending,isTrue);
    expect(facts.fee,isNull);
    final preview=WaffraSmsStructuredBankContext.parse(sms,sender:'AlRajhi');
    expect(preview.principalSar,isNull);
  });
}

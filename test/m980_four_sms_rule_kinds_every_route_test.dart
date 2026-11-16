import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
  defaultCategories, waffraM632ClassifySmsQueue;
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M980 #683: runnable cross-type regressions for the owner's four categories.
/// No real SMS, private account, finance authority or persisted ledger involved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rules = <WaffraSmsLocalRule>[
    WaffraSmsLocalRule(id:'m980_income',name:'Verified salary hint',
      kind:'income',income:true,category:'راتب / راتب أساسي',
      keywords:['راتب'],sender:'MyBank',matchAll:false),
    WaffraSmsLocalRule(id:'m980_expense',name:'Merchant expense hint',
      kind:'expense',income:false,category:'بقالة وتموين / سوبرماركت',
      keywords:['العثيم'],sender:'MyBank',matchAll:false),
    WaffraSmsLocalRule(id:'m980_transfer',name:'Transfer hint',
      kind:'transfer',income:false,category:'',
      keywords:['حوالة صادرة'],sender:'MyBank',matchAll:false),
    WaffraSmsLocalRule(id:'m980_excluded',name:'OTP exclusion',
      kind:'excluded',income:false,category:'',
      keywords:['رمز التحقق'],sender:'MyBank',matchAll:false),
  ];

  test('M980 one pass matches ALL FOUR saved/default rule groups together',(){
    const sms='راتب العثيم حوالة صادرة رمز التحقق 123456';
    final matched=WaffraSmsLocalRules.matchAllFourKinds(
      body:sms,sender:'MyBank',custom:rules);
    final saved=matched.where((r)=>!r.builtIn)
      .map((r)=>r.resolvedKind).toSet();
    expect(saved,{'income','expense','transfer','excluded'});
    final differentSender=WaffraSmsLocalRules.matchAllFourKinds(
      body:sms,sender:'OtherBank',custom:rules);
    expect(differentSender.where((r)=>!r.builtIn),isEmpty);
    // All four were MATCHED, but a conflicting bank/SMS cannot be posted.
    final safe=WaffraSmsLocalRules.resolveSpecial(
      body:sms,sender:'MyBank',
      bankKind:WaffraBankOperationKind.uncertain,custom:rules,
      matchedRules:matched,nativeSensitiveOtp:true);
    expect(safe,isNull);
    expect(WaffraSmsLocalRules.resolve(
      body:sms,sender:'MyBank',
      bankKind:WaffraBankOperationKind.uncertain,custom:rules,
      matchedRules:matched),isNull);
  });

  test('M980 one normalization is byte-equivalent across Arabic/English rules',(){
    for(final body in const <String>[
      'تـم إيداع راتب 7000 ريال', 'تم إيداع راتب 7000 ريال',
      'شراء عبر نقاط البيع التاجر العثيم', 'حوالة صادرة بمبلغ 90 ريال',
      'رمز التحقق ١٢٣٤٥٦', 'OTP code for your new app',
    ]){
      final text=WaffraSmsLocalRules.normalized(body);
      for(final rule in rules){
        expect(WaffraSmsLocalRules.matches(
          rule,body,sender:'MyBank',preNormalizedBody:text),
          WaffraSmsLocalRules.matches(rule,body,sender:'MyBank'),
          reason:'No classification drift for ${rule.id}');
      }
    }
  });

  test('M980 category evidence uses the same four-way matches and real bank direction',(){
    const income='تم إيداع راتب 7000 ريال في حسابك';
    const expense='شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم';
    const transfer='حوالة صادرة بين حساباتك بمبلغ 140 ريال';
    const exclusion='رمز التحقق: 123456';
    for(final row in <(String,String,WaffraBankOperationKind)>[
      (income,'income',WaffraBankOperationKind.income),
      (expense,'expense',WaffraBankOperationKind.expense),
      (transfer,'transfer',WaffraBankOperationKind.transfer),
      (exclusion,'excluded',WaffraBankOperationKind.uncertain),
    ]){
      final body=row.$1,expected=row.$2;
      final bank=WaffraBankSmsFactsParser.parse(body);
      expect(bank.kind,row.$3,reason:'real bank direction for $expected');
      final matched=WaffraSmsLocalRules.matchAllFourKinds(
        body:body,sender:'MyBank',custom:rules);
      expect(matched.where((r)=>!r.builtIn)
        .any((r)=>r.resolvedKind==expected),isTrue,reason:expected);
      final decided=expected=='income'||expected=='expense'?
        WaffraSmsLocalRules.resolve(body:body,sender:'MyBank',
          bankKind:bank.kind,custom:rules,matchedRules:matched):
        WaffraSmsLocalRules.resolveSpecial(body:body,sender:'MyBank',
          bankKind:bank.kind,custom:rules,matchedRules:matched);
      expect(decided?.resolvedKind,expected,reason:body);
    }
  });

  test('M980 conflicting saved exclusion versus confirmed income blocks autoPost',(){
    const body='تم إيداع راتب 7000 ريال في حسابك';
    const savedIncome=WaffraSmsLocalRule(
      id:'m980_posted_income',name:'Verified salary',kind:'income',
      income:true,category:'راتب / راتب أساسي',
      keywords:['راتب'],sender:'MyBank',matchAll:false,autoPost:true,
      accountId:'synthetic-verified-id',accountSuffix:'1234');
    const opposingExclude=WaffraSmsLocalRule(
      id:'m980_conflicting_exclusion',name:'Wrong salary exclusion',
      kind:'excluded',income:false,category:'',
      keywords:['راتب'],sender:'MyBank',matchAll:false);
    final facts=WaffraBankSmsFactsParser.parse(body);
    expect(facts.kind,WaffraBankOperationKind.income);
    final matches=WaffraSmsLocalRules.matchAllFourKinds(
      body:body,sender:'MyBank',
      custom:const [savedIncome,opposingExclude]);
    expect(matches.where((r)=>!r.builtIn)
      .map((r)=>r.resolvedKind).toSet(),{'income','excluded'});
    expect(WaffraSmsLocalRules.resolve(body:body,sender:'MyBank',
      bankKind:facts.kind,custom:const [savedIncome,opposingExclude],
      matchedRules:matches),isNull,
      reason:'A contradictory owner exclusion must block automatic posting');
  });

  test('M980 old safe exclusion guard is preserved for payment reminder cues',(){
    const body='Payment reminder: your bill is due tomorrow';
    const unsafePersonal=WaffraSmsLocalRule(
      id:'m980_overbroad_personal_exclude',name:'payment keyword',
      kind:'excluded',income:false,category:'',
      sender:'MyBank',keywords:['payment reminder'],matchAll:false);
    final matched=WaffraSmsLocalRules.matchAllFourKinds(
      body:body,sender:'MyBank',custom:const [unsafePersonal]);
    expect(matched.any((r)=>r.id==unsafePersonal.id),isTrue,
      reason:'The four-way matcher must still consider the owner rule');
    final resolved=WaffraSmsLocalRules.resolveSpecial(
      body:body,sender:'MyBank',bankKind:WaffraBankOperationKind.uncertain,
      custom:const [unsafePersonal],matchedRules:matched);
    expect(resolved?.id,isNot(unsafePersonal.id),
      reason:'Do not relax the legacy owner exclusion finance-action guard');
  });

  test('M980 independent direction cannot be inverted by a matching personal rule',(){
    const sms='شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم';
    const wrong=WaffraSmsLocalRule(id:'m980_wrong_income',
      name:'Wrong manual income',kind:'income',income:true,
      category:'راتب / راتب أساسي',keywords:['العثيم'],sender:'MyBank',
      matchAll:false);
    final m=WaffraSmsLocalRules.matchAllFourKinds(
      body:sms,sender:'MyBank',custom:const [wrong]);
    expect(m.where((r)=>!r.builtIn).single.resolvedKind,'income');
    final verified=WaffraBankSmsFactsParser.parse(sms);
    expect(verified.kind,WaffraBankOperationKind.expense);
    expect(WaffraSmsLocalRules.resolve(body:sms,sender:'MyBank',
      bankKind:verified.kind,custom:const [wrong],
      matchedRules:m),isNull);
  });

  test('M980 direct frontend/historical isolate uses four rules and does not post money',(){
    Map<String,Object?> sms(String id,String body,{bool sensitive=false})=>
      <String,Object?>{
        'id':id.padRight(64,'a'),'sender':'MyBank','body':body,
        'receivedAt':DateTime.utc(2026,11,15).millisecondsSinceEpoch,
        'sensitiveOtp':sensitive,
      };
    final rows=<Map<String,Object?>>[
      sms('1','تم إيداع راتب 7000 ريال في حسابك'),
      sms('2','شراء عبر نقاط البيع مبلغ 236 ريال التاجر العثيم'),
      sms('3','حوالة صادرة بين حساباتك بمبلغ 140 ريال'),
      sms('4','رمز التحقق: ••••••',sensitive:true),
    ];
    final result=waffraM632ClassifySmsQueue(<String,Object?>{
      'results':rows,
      'rules':rules.map((r)=>r.toJson()).toList(),
      'categories':defaultCategories().where((c)=>c.isSubcategory)
        .map((c)=>'${c.income?'1':'0'}:${c.name}').toList(),
      'hashes':<String>[],
    });
    final waiting=(result['waiting'] as List).cast<Map<String,Object?>>();
    final excluded=(result['excluded'] as List).cast<String>();
    expect(waiting.map((r)=>r['id']).toSet(),
      rows.take(3).map((r)=>r['id']).toSet());
    expect(excluded,[rows[3]['id']]);
    // All four kinds must be MATCHED. A financial category suggestion
    // remains optional when the independent amount/direction/SAR gates
    // cannot verify it; do not fabricate a 'local' category in that case.
    const expected=<String>['income','expense','transfer'];
    for(var i=0;i<expected.length;i++){
      final matches=WaffraSmsLocalRules.matchAllFourKinds(
        body:rows[i]['body'] as String,sender:'MyBank',custom:rules);
      expect(matches.where((r)=>!r.builtIn)
        .any((r)=>r.resolvedKind==expected[i]),isTrue);
      final suggested=waiting[i]['local'];
      if(suggested!=null){
        expect(suggested,isA<Map>());
        expect((suggested as Map)['kind'],expected[i]);
      }
    }
    expect(result['committed'],isEmpty);
  });

  test('M980 foreground/history + background share the SAME matcher before action',(){
    final main=File('lib/main.dart').readAsStringSync();
    final start=main.indexOf('Map<String,Object?> waffraM632ClassifySmsQueue(');
    final end=main.indexOf('List<String> splitBankMessages(',start);
    expect(start,greaterThanOrEqualTo(0));
    final foreground=main.substring(start,end);
    final fx=foreground.indexOf('WaffraSmsLocalRules.matchAllFourKinds(');
    expect(fx,greaterThanOrEqualTo(0));
    expect(fx,lessThan(foreground.indexOf('WaffraSmsLocalRules.resolveSpecial(')));
    expect(fx,lessThan(foreground.indexOf('WaffraSmsLocalRules.resolve(')));
    expect(foreground,contains('matchedRules:fourWay'));
    expect(foreground,contains("if(local['kind']=='excluded'){"));
    expect(foreground,isNot(contains('commitConfirmedSms(')));

    final home=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
    expect(home,contains('await compute(waffraM632ClassifySmsQueue'));
    expect(home,contains('await WaffraAutoSms.excludeMessages(batch)'));

    final worker=File('lib/waffra_auto_sms_autopost.part.dart')
      .readAsStringSync();
    final first=worker.indexOf('WaffraSmsLocalRules.matchAllFourKinds(');
    final special=worker.indexOf('WaffraSmsLocalRules.resolveSpecial(');
    final financial=worker.indexOf('WaffraSmsLocalRules.resolve(');
    expect(first,greaterThanOrEqualTo(0));
    expect(first,lessThan(special));
    expect(special,lessThan(financial));
    expect(worker,contains('matchedById[id]=fourWay'));
    expect(worker,contains('matchedRules:matchedById[id]'));
    expect(worker,contains('!matched.autoPost'));
    expect(worker,contains('matched.accountId.isEmpty'));
    expect(worker,contains('matched.accountSuffix.isEmpty'));
    expect(worker,contains('await WaffraAutoSms.excludeMessages([id])'));
  });
}

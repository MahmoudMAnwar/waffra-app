import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

/// M1007 / #721: owner-reviewed global vs sender-specific SMS rule scope.
void main() {
  const verification = 'رمز التحقق لتسجيل الدخول';
  const globalExclusion = WaffraSmsLocalRule(
    id:'m1007_global_exclusion',name:'رموز التحقق',
    keywords:['رمز التحقق'],income:false,category:'',
    kind:'excluded',sender:'',matchAll:false);

  test('M1007 senderless exclusion matches every sender by safe phrase', () {
    WaffraSmsLocalRules.validate(globalExclusion);
    for(final sender in <String>['Bank-A','App-B','NewSender']){
      expect(WaffraSmsLocalRules.matches(
        globalExclusion,verification,sender:sender),isTrue);
      final matched=WaffraSmsLocalRules.matchAllFourKinds(
        body:verification,sender:sender,custom:[globalExclusion]);
      expect(matched.any((r)=>r.id==globalExclusion.id),isTrue);
    }
    expect(WaffraSmsLocalRules.matches(globalExclusion,
      'Welcome to the bank',sender:'Bank-A'),isFalse);
  });

  test('M1007 sender-scoped rule never leaks across banks, indexed or plain', () {
    const scoped=WaffraSmsLocalRule(
      id:'m1007_scoped',name:'مرسل معين',keywords:['رمز التحقق'],
      income:false,category:'',kind:'excluded',
      sender:'Bank-A',matchAll:false);
    WaffraSmsLocalRules.validate(scoped);
    expect(WaffraSmsLocalRules.matches(
      scoped,verification,sender:'Bank-A'),isTrue);
    expect(WaffraSmsLocalRules.matches(
      scoped,verification,sender:'App-B'),isFalse);
    final index=WaffraSmsRuleCandidateIndex([scoped,globalExclusion]);
    for(final sender in ['Bank-A','App-B']){
      final matches=WaffraSmsLocalRules.matchAllFourKinds(
        body:verification,sender:sender,
        custom:[scoped,globalExclusion],candidateIndex:index);
      expect(matches.any((r)=>r.id==globalExclusion.id),isTrue);
      expect(matches.any((r)=>r.id==scoped.id),sender=='Bank-A');
    }
  });

  test('M1007 old encrypted JSON sender is retained; blank sender stays global', () {
    const scoped=WaffraSmsLocalRule(
      id:'m1007_legacy',name:'قاعدة قديمة',
      keywords:['رمز التحقق'],income:false,category:'',
      kind:'excluded',sender:'Bank-A');
    final original=scoped.toJson();
    expect(WaffraSmsLocalRule.fromJson(
      Map<String,dynamic>.from(original)).sender,'Bank-A');
    final senderless=Map<String,dynamic>.from(original)..remove('sender');
    expect(WaffraSmsLocalRule.fromJson(senderless).sender,'');
    expect(WaffraSmsLocalRules.matches(
      WaffraSmsLocalRule.fromJson(senderless),
      verification,sender:'DifferentApp'),isTrue);
  });

  test('M1007 explicitly global verified structural family stays safe', () {
    const learned=WaffraSmsLocalRule(
      id:'template_m1007_verification',name:'رسائل التحقق',
      keywords:['رمز التحقق'],income:false,category:'',
      kind:'excluded',sender:'',matchAll:true,
      templateFamily:'verification');
    WaffraSmsLocalRules.validate(learned);
    expect(WaffraSmsLocalRules.matches(
      learned,verification,sender:'AnyApp'),isTrue);
    expect(WaffraSmsLocalRules.matches(
      learned,'تم خصم 50 ريال، رمز التحقق',sender:'AnyApp'),isFalse);
  });

  test('M1007 a matching global excluded phrase never hides posted money', () {
    const mixed='تم خصم 50 ريال من حسابك، رمز التحقق لا تشاركه';
    final matched=WaffraSmsLocalRules.matchAllFourKinds(
      body:mixed,sender:'NewBank',custom:[globalExclusion]);
    final special=WaffraSmsLocalRules.resolveSpecial(
      body:mixed,sender:'NewBank',
      bankKind:WaffraBankOperationKind.expense,
      custom:[globalExclusion],matchedRules:matched);
    expect(special?.resolvedKind,isNot('excluded'));
  });

  test('M1007 owner scope editor shows both choices, impact and no global auto-post', () {
    final editor=File('lib/waffra_sms_rule_settings_page.dart')
      .readAsStringSync();
    final pipeline=File('lib/waffra_home_sms_rules.part.dart')
      .readAsStringSync();
    expect(editor,contains("Key('waffra-sms-scope-all-senders')"));
    expect(editor,contains("Key('waffra-sms-scope-specific-sender')"));
    expect(editor,contains('كل المرسلين'));
    expect(editor,contains('مرسل محدد'));
    expect(editor,contains("sender:allSenders?'':sender.text.trim()"));
    expect(editor,contains('if(allSenders)autoPost=false;'));
    expect(editor,contains('if(allSenders)...['));
    expect(editor,contains('if(!allSenders)TextField(controller:sender,'));
    expect(pipeline,contains('onRulesChanged:()=>_receiveAutoSmsNotice()'));
    expect(pipeline,contains("if(mounted&&ruleSaved==true)unawaited(_refreshAutoSmsInbox());"));
    final confirmation=File('lib/waffra_home_sms_confirmation.part.dart')
      .readAsStringSync();
    expect(confirmation,contains('تتعلم وفرة من التصحيح ده؟'));
    expect(confirmation,contains('confirmed.length!=1'));
    expect(confirmation,contains('await _openSmsRules('));
  });
}

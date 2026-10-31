import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ask_scope.dart';
import 'package:waffra/waffra_ai_finance_coach.dart';

void main() {
  test('M335 Ask Waffra consistently rejects unrelated Arabic and English', () {
    for (final question in [
      'ما هي عاصمة فرنسا؟', 'اعمل وصفة مكرونة', 'مين فاز في الماتش؟',
      'How is the weather?', 'Write me a poem', 'Who won the football game?',
      'احكيلي نكتة', 'حل واجب الفيزياء', 'امتى ماتش ريال مدريد؟',
    ]) {
      expect(WaffraAskScope.isRelated(question), isFalse,
          reason: question);
    }
    expect(WaffraAskScope.outsideResponse(),
      contains('اسألني عن دخلك'));
    expect(WaffraAskScope.outsideResponse(english:true),
      contains('inside the app'));
  });

  test('M335 real finance questions keep their verified-data path', () {
    for (final question in [
      'دخل كام الشهر ده؟','صرفت كام على المطاعم؟',
      'ازاي اوفر فلوسي؟','كم رصيد معاملاتي؟',
      'ميزانيتي الشهرية', 'ما هي أهداف الادخار؟',
      'How much did I spend this week?',
      'Show my budget and subscriptions',
      'كم سعر الذهب؟','محتاج أحلل فواتيري',
    ]) {
      expect(WaffraAskScope.isRelated(question), isTrue,
          reason: question);
    }
    expect(WaffraAskScope.isRelated(''), isFalse);
  });

  test('M335 scope is enforced in widget before model/finance access', () {
    final home=File('lib/waffra_smart_features.dart').readAsStringSync();
    final method=home.substring(
      home.indexOf('void _ask(){'),home.indexOf('Widget _assistant(){'));
    expect(method.indexOf('WaffraAskScope.isRelated(q)'),
      lessThan(method.indexOf('WaffraAiRecordedAnswers.answer(')));
    expect(method, contains('WaffraAskScope.outsideResponse('));
  });

  test('M335 direct AI helper never invokes Qwen for unrelated questions', () async {
    var called=0;
    final summary=WaffraAiFinanceCoach.summarize([
      const WaffraAiLedgerFact(category:'الراتب',
        amountMinor:100000,income:true),
    ]);
    final result=await WaffraAiFinanceCoach.askWaffra(
      'What is the capital of Japan?',summary,
      generate:(_)async{called++;return 'Tokyo';},english:true);
    expect(result,WaffraAskScope.outsideResponse(english:true));
    expect(called,0);
  });
}

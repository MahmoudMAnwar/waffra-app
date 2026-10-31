import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ai_finance_brain.dart';
import 'package:waffra/waffra_ai_finance_coach.dart';

void main() {
  String model(List<Map<String,Object?>> rows)=>
    jsonEncode({'transactions': rows});
  Map<String,Object?> tx(String quote,String amount,String currency,
      String direction,{String? merchant})=> {
    'source_quote':quote,'amount_text':amount,
    'currency_text':currency,'direction':direction,'merchant':merchant,
  };

  test('M317 Arabic OCR with independent bank notices counts 2 actions',()async{
    const text='حوالة واردة 100 ريال سعودي\nشراء POS SAR 30.50';
    final result=await WaffraAiFinanceBrain.imageOcr(text,generate:(_)async=>
      model([
        tx('حوالة واردة 100 ريال سعودي','100','ريال سعودي','income'),
        tx('شراء POS SAR 30.50','30.50','SAR','expense',
            merchant:'متجر'),
      ]));
    expect(result.error,isNull);
    expect(result.count,2);
    expect(result.items.map((e)=>e.position),[1,2]);
    expect(result.items.map((e)=>e.direction),
        [WaffraAiDirection.income,WaffraAiDirection.expense]);
    expect(result.needsReviewCount,0);
  });

  test('M317 one receipt with many products is ONE transaction',()async{
    const text='Market\nMilk 10\nBread 5\nVAT 2.25\nTotal SAR 17.25';
    final result=await WaffraAiFinanceBrain.imageOcr(text,generate:(_)async=>
      model([tx('Total SAR 17.25','17.25','SAR','expense')]));
    expect(result.error,isNull);
    expect(result.count,1);
  });

  test('M317 Qwen cannot invent a financial amount',()async{
    const text='Purchase SAR 50.00';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'5000','SAR','expense')]));
    expect(result.error,isNull);
    expect(result.count,1);
    expect(result.items.single.amountText,isNull);
    expect(result.items.single.needsReview,isTrue);
    expect(result.items.single.reason,'amount_not_verified');
  });

  test('M317 foreign JOD is never silently reinterpreted as SAR',()async{
    const text='حوالة واردة JOD198.125';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'198.125','JOD','income')]));
    expect(result.error,isNull);
    expect(result.items.single.currency,'JOD');
    expect(result.items.single.needsReview,isTrue);
    expect(result.items.single.reason,'foreign_currency_review');
  });

  test('M317 foreign named QAR cannot be guessed as Saudi Riyal',()async{
    const text='تحويل وارد 100 ريال قطري';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'100','ريال سعودي','income')]));
    expect(result.items.single.currency,isNull);
    expect(result.items.single.needsReview,isTrue);
    expect(result.items.single.reason,'currency_not_verified');
  });

  test('M317 Arabic and Persian digits retain source evidence',()async{
    const text='تم شراء SAR ١٩٫٥٠';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'١٩٫٥٠','SAR','expense')]));
    expect(result.items.single.amountText,'١٩٫٥٠');
    expect(result.items.single.needsReview,isFalse);
  });

  test('M317 unsupported currency requires manual review',()async{
    const text='تم شراء 19.50 ريال يمني';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'19.50','ريال يمني','expense')]));
    expect(result.items.single.currency,isNull);
    expect(result.items.single.needsReview,isTrue);
  });

  test('M317 unsafe status cannot become confirmed debit',()async{
    const text='Purchase SAR 20 pending';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'20','SAR','expense')]));
    expect(result.items.single.reason,'unconfirmed');
    expect(result.items.single.needsReview,isTrue);
  });

  test('M317 currency mentioned only in balance is NOT source evidence',()async{
    const text='Purchase 100 Balance SAR 250';
    final result=await WaffraAiFinanceBrain.bankSms(text,generate:(_)async=>
      model([tx(text,'100','SAR','expense')]));
    expect(result.count,1);
    expect(result.items.single.needsReview,isTrue);
    expect(result.items.single.reason,'currency_not_verified');
  });

  test('M317 two competing action amounts require review',()async{
    const text='شراء POS SAR 10.00 SAR 20.00';
    final result=await WaffraAiFinanceBrain.imageOcr(text,generate:(_)async=>
      model([tx(text,'10.00','SAR','expense')]));
    expect(result.items.single.needsReview,isTrue);
    expect(result.items.single.reason,'competing_amounts');
  });

  test('M317 duplicate model item cannot double-count one payment',()async{
    const text='شراء POS SAR 20.00';
    final result=await WaffraAiFinanceBrain.imageOcr(text,generate:(_)async=>
      model([tx(text,'20.00','SAR','expense'),
        tx(text,'20.00','SAR','expense')]));
    expect(result.error,'untrusted_model_output');
    expect(result.count,0);
  });

  test('M317 ungrounded text and malformed JSON fail closed',()async{
    const text='شراء POS SAR 20.00';
    final hallucinated=await WaffraAiFinanceBrain.imageOcr(
      text,generate:(_)async=>model([tx('Some other payment','20','SAR','expense')]));
    expect(hallucinated.count,0);
    expect(hallucinated.error,'untrusted_model_output');
    final malformed=await WaffraAiFinanceBrain.bankSms(
      text,generate:(_)async=>'{"transactions":');
    expect(malformed.error,'untrusted_model_output');
  });

  test('M317 never sends empty input or oversized OCR text to model',()async{
    var invoked=0;
    Future<String> generator(String _)async{
      invoked++;
      return model([]);
    }
    expect((await WaffraAiFinanceBrain.imageOcr('',
        generate:generator)).error,'invalid_input');
    expect((await WaffraAiFinanceBrain.imageOcr(
        'x'*12001,generate:generator)).error,'invalid_input');
    expect(invoked,0);
  });

  test('M318 verified integer snapshot powers three read-only AI skills',()async{
    final summary=WaffraAiFinanceCoach.summarize([
      const WaffraAiLedgerFact(
        category:'راتب',amountMinor:100000,income:true),
      const WaffraAiLedgerFact(
        category:'مطاعم',amountMinor:12550,income:false),
      const WaffraAiLedgerFact(
        category:'مطاعم',amountMinor:250,income:false),
      const WaffraAiLedgerFact(
        category:'مواصلات',amountMinor:2000,income:false),
    ]);
    expect(summary.incomeMinor,100000);
    expect(summary.expenseMinor,14800);
    expect(summary.netMinor,85200);
    expect(summary.expenseByCategory['مطاعم'],12800);
    expect(summary.transactionCount,4);
    var prompts=<String>[];
    Future<String> generator(String p)async{
      prompts.add(p);
      return 'اقتراح: راجع مصروفات المطاعم.';
    }
    expect(await WaffraAiFinanceCoach.askWaffra(
      'فلوسي بتروح فين؟',summary,generate:generator),isNotNull);
    expect(await WaffraAiFinanceCoach.analysis(
      summary,generate:generator),isNotNull);
    expect(await WaffraAiFinanceCoach.savingSuggestions(
      summary,generate:generator),isNotNull);
    expect(prompts.length,3);
    for(final prompt in prompts){
      expect(prompt,contains('"income_minor":100000'));
      expect(prompt,contains('"expense_minor":14800'));
      expect(prompt,isNot(contains('Bank SMS')));
    }
  });

  test('M318 unknown/empty summary does not invent spending insights',()async{
    final empty=WaffraAiFinanceCoach.summarize(const []);
    expect(await WaffraAiFinanceCoach.askWaffra('Any data?',empty,
        generate:(_)async=>'made up facts'),contains('inside the app'));
  });

  test('M317 currency list covers all 36 app display currencies',(){
    expect(WaffraAiFinanceBrain.supported.length,36);
    expect(WaffraAiFinanceBrain.currencyNames.length,36);
    for(final entry in WaffraAiFinanceBrain.currencyNames.entries){
      expect(WaffraAiFinanceBrain.currencyCode(entry.key),entry.value);
    }
  });
}

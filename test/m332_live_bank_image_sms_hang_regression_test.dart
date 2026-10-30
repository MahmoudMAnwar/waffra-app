import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_ai_finance_brain.dart';

void main(){
 const threeBankBubbles='''شراء PoS
 عبر:7678-مدى
 SAR 4.50
 Merchant Test
 30/10/26 23:49
 شراء PoS
 عبر:7678-مدى
 SAR 10
 Merchant Test
 30/10/26 00:01
 شراء PoS
 عبر:7678-مدى
 SAR 4
 Merchant Test
 30/10/26 14:44''';

 test('M332 screenshot with exactly three bank bubbles stays three',(){
  final entries=WaffraBankScreenshotParser.reviewItems(threeBankBubbles);
  expect(entries.length,3);
  expect(entries.map((e)=>e.amount).toList(),[4.5,10.0,4.0]);
  expect(entries.every((e)=>!e.income),true);
 });

 test('M332 nearby POS synonyms do not double count a payment',(){
  final entries=WaffraBankScreenshotParser.reviewItems(
    'شراء POS\\nSAR 4.50\\nCoffee\\nشراء POS\\nSAR 10.00\\nCoffee');
  expect(entries.length,2);
  expect(entries.map((e)=>e.amount).toList(),[4.5,10]);
 });

 test('M332 short Arabic inbound and outbound SR amounts ignore account IDs',(){
  const messages=[
   'حوالة داخلية واردة بSR 15.50\\nل9288\\nمن4388;مرسل تجريبي\\n7/10/26 11:49',
   'شراء PoS\\nعبر:7678;مدى-مدى باي\\nبSAR 74\\nمتجر تجريبي\\n7/10/26 21:59',
   'حوالة داخلية صادرة بSR 60\\nمن9288\\nل4643;مستلم تجريبي\\n17/10/26 12:34',
   'حوالة داخلية صادرة بSR 25\\nمن9288\\nل5077;مستلم تجريبي\\n16/10/26 19:23'
  ];
  final results=[for(final s in messages) BankParser.parse(s)];
  expect(results.map((e)=>e.amount).toList(),[15.5,74.0,60.0,25.0]);
  expect(results.map((e)=>e.income).toList(),[true,false,false,false]);
 });

 test('M332 AI cannot double 3 OCR actions even if quotes come from image',()async{
  final quotes=WaffraBankScreenshotParser.reviewItems(threeBankBubbles);
  Map<String,Object?> tx(String quote,num amount)=> {
   'source_quote':quote,'amount_text':amount.toString(),
   'currency_text':'SAR','direction':'expense','merchant':null
  };
  final input=threeBankBubbles;
  final six=await WaffraAiFinanceBrain.imageOcr(input,generate:(_)async=>
    jsonEncode({'transactions':[
      for(final e in quotes) tx(e.sourceText,e.amount!),
      for(final e in quotes) tx(e.sourceText.split('\\n').first,e.amount!)
    ]}));
  // Either strict validation rejects duplicated source, or the independent
  // image count and per-amount checks reject the 6-for-3 suggestion.
  expect(WaffraAiFinanceBrain.matchesVerifiedImageActions(input,six),false);
  final correct=await WaffraAiFinanceBrain.imageOcr(input,generate:(_)async=>
    jsonEncode({'transactions':[
      for(final e in quotes) tx(e.sourceText,e.amount!)
    ]}));
  expect(correct.count,3);
  expect(WaffraAiFinanceBrain.matchesVerifiedImageActions(input,correct),true);
  final wrong=await WaffraAiFinanceBrain.imageOcr(input,generate:(_)async=>
    jsonEncode({'transactions':[
      tx(quotes.first.sourceText,10),
      tx(quotes[1].sourceText,10),
      tx(quotes.last.sourceText,4)
    ]}));
  expect(WaffraAiFinanceBrain.matchesVerifiedImageActions(input,wrong),false);
 });

 test('M332 AI progress is cancellable and bank AI starts on every paste',(){
  final home=File('lib/main.dart').readAsStringSync();
  final engine=File('lib/waffra_ondevice_qwen.dart').readAsStringSync();
  expect(home,contains("Key('waffra-ai-analysis-cancel')"));
  expect(home,contains('scheduleBankSmsAnalysis(ctx,update,text);'));
  expect(home,contains('analyzeBankSmsAutomatically('));
  expect(home,isNot(contains("Key('waffra-sms-ai-review')")));
  expect(engine,contains('cancelCurrentGeneration()'));
  expect(engine,contains('generationTimeLimit'));
  expect(engine,contains('cancelGeneration()'));
 });
}

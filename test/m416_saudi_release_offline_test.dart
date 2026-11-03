import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/waffra_saudi_release.dart';
import '../lib/waffra_saudi_ask.dart';
import '../lib/waffra_display_currency.dart';
import '../lib/waffra_regional_copy.dart';
import '../lib/waffra_sms_intelligence.dart';
import '../lib/main.dart' show BankParser;

void main(){
 setUp((){
  SharedPreferences.setMockInitialValues(<String,Object>{});
 });
 test('M416 Saudi release switches preserve Global features in source',(){
  expect(WaffraSaudiRelease.enabled,isTrue);
  expect(WaffraSaudiRelease.locationCountryOnboarding,isFalse);
  expect(WaffraSaudiRelease.receiptImageTransactionImport,isFalse);
  expect(WaffraSaudiRelease.qwenForBankSms,isFalse);
  expect(WaffraSaudiRelease.qwenForAskWaffra,isFalse);
  expect(WaffraSaudiRelease.freeTextAskWaffra,isFalse);
  expect(WaffraSaudiRelease.userCountryChoice,isFalse);
  expect(WaffraSaudiRelease.userCurrencyChoice,isFalse);
  expect(WaffraSaudiRelease.globalCurrencyConverter,isTrue);
  expect(WaffraSaudiRelease.bankSmsForeignCurrencyPreview,isFalse);
  expect(WaffraSaudiRelease.ledgerCurrency,'SAR');
 });
 test('M416 old foreign display preference is preserved but not applied',()async{
  SharedPreferences.setMockInitialValues({
   'waffra_display_country_currency_v1':'EGP',
  });
  await WaffraDisplayCurrency.initialize();
  expect(WaffraDisplayCurrency.country.code,'SAR');
  expect(WaffraDisplayCurrency.convert(123.45),123.45);
  expect(WaffraDisplayCurrency.toLedgerSar(123.45),123.45);
  await expectLater(WaffraDisplayCurrency.setCurrency('EGP'),throwsStateError);
  final prefs=await SharedPreferences.getInstance();
  expect(prefs.getString('waffra_display_country_currency_v1'),'EGP');
 });
 test('M416 older country dialect preference remains stored but Saudi tone runs',()async{
  SharedPreferences.setMockInitialValues({
   'waffra_ui_country_iso_v1':'EG',
  });
  final prefs=await SharedPreferences.getInstance();
  await WaffraRegionalCopy.initialize(prefs);
  expect(WaffraRegionalCopy.isSaudi,isTrue);
  expect(WaffraRegionalCopy.arabicCountrySubtag,'SA');
  expect(WaffraRegionalCopy.text(
   english:false,standard:'Standard',saudi:'Saudi',en:'English',
   egyptian:'Egyptian',country:'EG'),'Saudi');
  await expectLater(WaffraRegionalCopy.setCountry('EG'),throwsStateError);
  expect(prefs.getString('waffra_ui_country_iso_v1'),'EG');
 });
 group('M416 deterministic Ask Waffra',(){
  final now=DateTime(2026,11,2);
  final facts=<WaffraSaudiAskEntry>[
   WaffraSaudiAskEntry(DateTime(2026,11,1),'راتب',500000,true),
   WaffraSaudiAskEntry(DateTime(2026,11,1),'مطاعم',4000,false),
   WaffraSaudiAskEntry(DateTime(2026,11,2),'مطاعم',6000,false),
   WaffraSaudiAskEntry(DateTime(2026,10,31),'مطاعم',999999,false),
  ];
  final budgets=<WaffraSaudiAskBudget>[
   WaffraSaudiAskBudget('food','ميزانية الأكل',20000,10000,true),
   WaffraSaudiAskBudget('fuel','بنزين',10000,0,false),
  ];
  String m(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';
  String answer(String key)=>WaffraSaudiAsk.answer(key,facts,budgets,
   now:now,money:m);
  test('month scope excludes history without altering source records',(){
   expect(answer('income'),contains('5000.00 SAR'));
   expect(answer('expenses'),contains('100.00 SAR'));
   expect(answer('net'),contains('4900.00 SAR'));
   expect(facts.length,4);
  });
  test('category and highest expense answers are from posted entries',(){
   expect(answer('top'),contains('مطاعم'));
   expect(answer('top'),contains('100.00 SAR'));
   expect(answer('category:مطاعم'),contains('100.00 SAR'));
  });
  test('budget answers use budget link totals, not category guesses',(){
   expect(answer('budget:food'),contains('200.00 SAR'));
   expect(answer('budget:food'),contains('100.00 SAR'));
   expect(answer('budget_summary'),contains('300.00 SAR'));
   expect(answer('budget:fuel'),contains('متوقفة'));
  });
  test('all questions are fixed, with no freeform chat or model',(){
   final list=WaffraSaudiAsk.questions(facts,budgets,now:now);
   expect(list.any((q)=>q.id=='income'),isTrue);
   expect(list.any((q)=>q.id=='budget:food'),isTrue);
   expect(list.any((q)=>q.id=='category:مطاعم'),isTrue);
   expect(answer('do-whatever-the-user-types'),contains('اختر سؤالًا'));
  });
  test('empty data provides measured zeros, not invented balances',(){
   final value=WaffraSaudiAsk.answer('expenses',[],[],
    now:now,money:m);
   expect(value,contains('0.00 SAR'));
  });
 });
 test('M416 local Saudi and English SMS classify without Qwen',(){
  const arabic='شراء PoS\n\nمن2912;مدى-mada Pay\n\nبـ84.72SR\n00:43 16/10/26';
  final spent=BankParser.parse(arabic);
  expect(spent.amount,84.72);
  expect(spent.income,isFalse);
  const incoming='Credit Transfer via Alinma Bank\n'
   'Amount: 1,900 SAR\nFrom: Sender\nDate: 2026-11-01 08:46';
  final received=BankParser.parse(incoming);
  expect(received.income,isTrue);
  expect(received.amount,1900.0);
  expect(received.requiresCurrencyReview,isFalse);
  final intent=WaffraSmsIntelligence.classify(incoming);
  expect(intent.requiresCurrencyReview,isFalse);
  expect(BankParser.parse('JOD198.000 credited via CliQ transfer').amount,isNull,
   reason:'Foreign amounts must never silently be written as SAR.');
 });
}
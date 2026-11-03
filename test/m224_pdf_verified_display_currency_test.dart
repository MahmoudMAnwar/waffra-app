import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:waffra/waffra_display_currency.dart';

/// User-approved global denomination is a caption-only setting. It must not
/// turn 1,000 financial units into an FX conversion; FX tool is separate.
void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(() {
  SharedPreferences.setMockInitialValues(<String,Object>{});
  WaffraDisplayCurrency.active.value=WaffraDisplayCurrency.displaySelection('SAR');
 });
 tearDown(() {
  WaffraDisplayCurrency.active.value=WaffraDisplayCurrency.displaySelection('SAR');
 });
 test('M416 Saudi edition keeps SAR and preserves legacy Global selection',()async{
  final noNetwork=MockClient((_)async {
   fail('Saudi app currency must never request FX network rates');
   return http.Response('',503);
  });
  try {
   SharedPreferences.setMockInitialValues({
    'waffra_display_country_currency_v1':'EGP',
   });
   await WaffraDisplayCurrency.initialize(client:noNetwork);
   expect(WaffraDisplayCurrency.country.code,'SAR');
   expect(WaffraDisplayCurrency.convert(1000),1000);
   expect(WaffraDisplayCurrency.toLedgerSar(1000),1000);
   expect(WaffraDisplayCurrency.amount(1000),'1,000.00');
   expect(WaffraDisplayCurrency.money(1000,english:true),'1,000.00 SAR');
   await expectLater(
    WaffraDisplayCurrency.setCurrency('EGP',client:noNetwork),
    throwsStateError);
   final p=await SharedPreferences.getInstance();
   expect(p.getString('waffra_display_country_currency_v1'),'EGP');
   expect(WaffraDisplayCurrency.displaySelection('EGP').fromSar(1000),1000);
   await WaffraDisplayCurrency.refresh(client:noNetwork);
   expect(WaffraDisplayCurrency.country.code,'SAR');
  }finally{noNetwork.close();}
 });
 test('M225: verified FX parser exists for tools, not app display selection',(){
  final now=DateTime.utc(2026,10,25,10);
  final quote=WaffraDisplayCurrency.primaryRate({
   'result':'success',
   'rates':{'SAR':3.75,'EGP':50.0,'USD':1.0},
   'time_last_update_unix':now.millisecondsSinceEpoch~/1000,
  },'EGP',now:now);
  expect(quote.fromSar(100),closeTo(1333.3333333,0.0001));
  expect(quote.toSar(1333.3333333),closeTo(100,0.0001));
  expect(WaffraDisplayCurrency.displaySelection('EGP').fromSar(100),100);
 });
 test('M224: absent and stale FX values are rejected not renamed',(){
  final now=DateTime.utc(2026,10,25,10);
  expect(()=>WaffraDisplayCurrency.primaryRate({
   'result':'success','rates':{'SAR':3.75,'EGP':50},
  },'EGP',now:now),throwsFormatException);
  expect(()=>WaffraDisplayCurrency.primaryRate({
   'result':'success','rates':{'SAR':3.75,'EGP':50},
   'time_last_update_unix':now.subtract(const Duration(days:9))
     .millisecondsSinceEpoch~/1000,
  },'EGP',now:now),throwsFormatException);
  const unavailable=WaffraVerifiedDisplayQuote(
   code:'EGP',sarToSelected:null,updatedAtUtc:null,provider:'no-source');
  expect(unavailable.verified,isFalse);
  expect(unavailable.fromSar(100),isNull);
  expect(unavailable.toSar(100),isNull);
 });
 test('M224: every PDF chart, table, header has the captured verified unit',(){
  final app=File('lib/main.dart').readAsStringSync();
  final start=app.indexOf('Future<void> exportEntriesPdf(');
  final end=app.indexOf('final bytes=await doc.save()',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final pdf=app.substring(start,end);
  expect(pdf,contains('final pdfQuote=WaffraDisplayCurrency.active.value;'));
  expect(pdf,contains('if(!pdfQuote.verified)'));
  expect(pdf,contains('final n=pdfAmount(number);'));
  expect(pdf,contains('pdfQuote.fromSar(sar)'));
  expect(pdf,contains('Amount (\$pdfCurrency)'));
  expect(pdf,contains('المبلغ (\$pdfCurrencyAr)'));
  expect(pdf,contains('svg:weeklySpendSvg(smartData!.weeklySpend.map(pdfAmount).toList())'));
  expect(pdf,contains('svg:pairedBarChartSvg(buckets.map('));
  expect(pdf,contains('pdfAmount(p.\$1)'));
  expect(pdf.contains('Amount (SAR)'),isFalse);
  expect(pdf.contains('Expenses (SAR)'),isFalse);
  expect(pdf.contains('المبلغ (ريال)'),isFalse);
  expect(pdf.contains('المصروفات (ريال)'),isFalse);
 });
}

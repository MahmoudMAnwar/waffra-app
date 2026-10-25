import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_display_currency.dart';

/// Real money never changes denomination by renaming a unit. The underlying
/// finance snapshot remains SAR; reports use a single validated FX quote.
void main() {
 test('M224: Egyptian country choice converts SAR values, not labels only',(){
  final now=DateTime.utc(2026,10,25,10);
  final quote=WaffraDisplayCurrency.primaryRate({
   'result':'success',
   'rates':{'SAR':3.75,'EGP':50.0,'USD':1.0},
   'time_last_update_unix':now.millisecondsSinceEpoch~/1000,
  },'EGP',now:now);
  expect(quote.verified,isTrue);
  expect(quote.fromSar(100),closeTo(1333.3333333,0.0001));
  expect(quote.toSar(1333.3333333),closeTo(100,0.0001));
  expect(waffraCountry('EGP').symbolAr,'ج.م');
  expect(waffraCountry('SAR').symbolAr,'ريال');
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

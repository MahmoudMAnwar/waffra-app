import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_foreign_currency_preview.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
 WaffraSmsFxQuote freshQuote() {
  final now=DateTime.now().toUtc();
  return WaffraSmsFxQuote.fromUsdRates({
   'result':'success','rates':{'USD':1,'AED':3.67,'SAR':3.75},
   'time_last_update_unix':
    now.subtract(const Duration(hours:2)).millisecondsSinceEpoch~/1000,
  },originalCurrency:'AED',targetCurrency:'SAR',
    now:now,provider:'ExchangeRate-API');
 }

 testWidgets('M336 foreign FX requires explicit approval and shows the source',
    (tester) async {
  late Future<WaffraSmsFxReview?> pending;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   Builder(builder:(ctx)=>FilledButton(
    onPressed:(){pending=WaffraForeignCurrencyPreview.show(ctx,
      originalAmount:136,originalCurrency:'AED',
      targetCurrency:'SAR',english:false,
      fetchQuote:(source,target)async{
       expect(source,'AED');expect(target,'SAR');return freshQuote();
      });},
    child:const Text('Start FX review'))))));
  await tester.tap(find.text('Start FX review'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-fx-consent-preview')),findsOneWidget);
  expect(find.textContaining('ExchangeRate-API'),findsOneWidget);
  expect(find.textContaining('136.00 AED'),findsOneWidget);
  expect(find.textContaining('SAR'),findsWidgets);
  await tester.tap(find.text('الموافقة على المعاينة'));
  await tester.pumpAndSettle();
  final approved=await pending;
  expect(approved,isNotNull);
  expect(approved!.originalCurrency,'AED');
  expect(approved.convertedCurrency,'SAR');
  expect(approved.originalAmount,136);
  expect(approved.convertedAmount,greaterThan(136));
  expect(approved.rateProvider,'ExchangeRate-API');
  final snapshot=approved.toProvenanceJson();
  expect(WaffraSmsFxReview.fromProvenanceJson(snapshot).convertedMinor,
   approved.convertedMinor);
 });

 testWidgets('M336 reject quote does not create an approval', (tester) async {
  late Future<WaffraSmsFxReview?> pending;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:
   Builder(builder:(ctx)=>FilledButton(
    onPressed:(){pending=WaffraForeignCurrencyPreview.show(ctx,
      originalAmount:136,originalCurrency:'AED',
      targetCurrency:'SAR',english:false,
      fetchQuote:(a,b)async=>freshQuote());},
    child:const Text('Review'))))));
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ليس الآن'));
  await tester.pumpAndSettle();
  expect(await pending,isNull);
 });

 test('M336 source guard: no foreign-SAR write without encrypted FX',(){
  final app=File('lib/main.dart').readAsStringSync();
  final beginning=app.indexOf('Future<void> _previewForeignBankCurrency(');
  final end=app.indexOf('Future<bool> _canReviewOcrAsLedgerTransaction(',beginning);
  final handler=app.substring(beginning,end);
  expect(handler,contains('WaffraForeignCurrencyPreview.show('));
  expect(handler,isNot(contains('commitConfirmedSms(')));
  expect(handler,isNot(contains('entries.insert(')));
  expect(app,contains('WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)'));
  expect(app,contains('WaffraBankScreenshotParser.requiresForeignCurrencyReview('));
  expect(app,contains("key:const Key('waffra-fx-quote-preview-action')"));
  expect(app,contains("key:const Key('waffra-fx-transaction-preview')"));
 });

 test('M336 title is not forced into a single line',(){
  final app=File('lib/main.dart').readAsStringSync();
  final start=app.indexOf('Widget compactTransaction(MoneyEntry entry)');
  final end=app.indexOf('Widget dashboard()',start);
  expect(app.substring(start,end),contains('WaffraText(entry.title,maxLines:3'));
 });

 test('M336 unsupported, mixed and stale FX cannot be silently saved',(){
  expect(WaffraSmsCurrencies.originalAmount(
    'Money received USD 10 and EUR 20 Balance 1 SAR'),isNull);
  expect(() => WaffraSmsFxQuote.fromUsdRates({
    'result':'success','rates':{'USD':1,'AED':3.67,'SAR':3.75},
    'time_last_update_unix':DateTime.now().toUtc().subtract(
      const Duration(days:9)).millisecondsSinceEpoch~/1000,
   },originalCurrency:'AED',targetCurrency:'SAR'),
    throwsFormatException);
 });
}

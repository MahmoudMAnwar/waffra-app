import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/waffra_receipt_ocr_parser.dart';

void main(){
 BudgetCategory cat(String id,String name,{String parentId='',bool income=false})=>
  BudgetCategory(id:id,name:name,icon:'receipt',color:0xFF087A54,
   income:income,parentId:parentId);

 test('M336 whole-app category routing rejects wrong parent and income',(){
  final catalog=[
   cat('expense','مصروفات'),
   cat('restaurants','مطاعم'),
   cat('lunch','مطاعم / وجبات',parentId:'restaurants'),
   cat('electric','مصروفات / كهرباء',parentId:'expense'),
   cat('income','الدخل',income:true),
   cat('salary','الدخل / راتب',parentId:'income',income:true),
  ];
  expect(waffraManualCategoryParents(catalog,false).length,2);
  expect(waffraManualCategoryChildren(catalog,false,'restaurants')
    .map((e)=>e.name),['مطاعم / وجبات']);
  expect(waffraManualCategoryChildren(catalog,true,'income')
    .map((e)=>e.name),['الدخل / راتب']);
  expect(waffraCanAssignManualCategory(catalog,false,'restaurants',
    'مطاعم / وجبات'),true);
  expect(waffraCanAssignManualCategory(catalog,false,'expense',
    'مطاعم / وجبات'),false);
  expect(waffraCanAssignManualCategory(catalog,false,'income',
    'الدخل / راتب'),false);
  expect(waffraCanAssignManualCategory(catalog,false,'restaurants',
    'مطاعم'),false);
 });

 test('M336 transaction metadata edit/backup round-trip preserves full title',(){
  final entry=MoneyEntry(
   id:'test',title:'معاملة بعملة تحتاج مراجعة',
   category:'مصروفات / كهرباء',income:false,amount:136,
   date:DateTime(2026,10,31),sourceType:'sms',
   merchantKey:'test-merchant',notes:'Bank text is only a synthetic fixture');
  final restored=MoneyEntry.fromJson(entry.toJson());
  expect(restored.title,'معاملة بعملة تحتاج مراجعة');
  expect(restored.amount,136);
  expect(restored.income,false);
  final moved=restored.withCategory('مطاعم / وجبات');
  expect(moved.title,restored.title);
  expect(moved.date,restored.date);
  expect(moved.notes,restored.notes);
  expect(moved.sourceType,'sms');
  expect(moved.merchantKey,'test-merchant');
  expect(waffraTransactionTitleAllowed(restored.title),true);
 });

 test('M336 all currencies retain source precision and prevent false SAR',(){
  expect(WaffraSmsCurrencies.supported.length,36);
  for(final code in WaffraSmsCurrencies.supported){
   final precision=WaffraSmsCurrencies.minorDigits(code);
   final amount=precision==0?'21':precision==3?'21.125':'21.25';
   final text='Incoming Transfer\nAmount '+amount+' '+code+
    '\nBalance: 999 '+code;
   expect(WaffraSmsCurrencies.currenciesForMessage(text),{code},
    reason:code);
   expect(WaffraSmsCurrencies.originalAmount(text)?.currency,code,
    reason:code);
   expect(WaffraSmsCurrencies.requiresReviewForSarLedger(text),code!='SAR',
    reason:code);
   expect(WaffraCurrencyMinor.exact(double.parse(amount),code),isNotNull);
  }
 });

 test('M336 OCR never silently saves screenshot timestamp as merchant',(){
  final receipt=WaffraReceiptOcrParser.parse(
    'Yesterday • 11:48 pm\nشراء PoS\nSAR 4.50\nJoanna Sa\n'
    '30/10/26 23:49');
  expect(receipt.merchant,isNull);
  expect(receipt.amount,isNull);
 });

 test('M336 previously saved wrong-currency titles are flagged without edits',(){
   final suspicious=MoneyEntry(id:'legacy',title:'معاملة بعملة تحتاج مراجعة',
    amount:136,income:false,category:'أخرى',date:DateTime(2026,10,31),
    sourceType:'sms');
   expect(waffraNeedsLegacyFxReview(suspicious),isTrue);
   expect(waffraNeedsLegacyFxReview(
     MoneyEntry.fromJson(suspicious.toJson())),isTrue);
   final manual=MoneyEntry(id:'manual',title:suspicious.title,
    amount:136,income:false,category:'أخرى',date:DateTime(2026,10,31));
   expect(waffraNeedsLegacyFxReview(manual),isFalse);
   final app=File('lib/main.dart').readAsStringSync();
   expect(app,contains("Key('waffra-legacy-foreign-currency-review-warning')"));
   expect(app,contains('may include unverified amounts'));
 });

  test('M337 newly created SMS category stays under selected parent',(){
  final app=File('lib/main.dart').readAsStringSync();
  final from=app.indexOf('Future<void> entrySheet(');
  final to=app.indexOf('Future<String?> chooseTransactionCategory(',from);
  final section=app.substring(from,to);
  expect(section,contains('categoryDialog(income:income,parentId:mainId,'));
  expect(section,contains('categoryDialog(income:income,parentId:mainId);'));
  expect(section,contains('selectedParentId=mainId;category=c.name'));
  expect(section,contains('Select a main category first.'));
 });

  test('M336 original currency totals are separated and never sum FX',(){
  final summary=WaffraSmsCurrencies.sourceTotals([
   'AED debited from account 136.00 ending with 1001 at SARAYA HALAB. Balance: 4857.96 AED',
   'شراء PoS SAR 4.50',
   'Incoming Transfer JOD 2.125 Balance 90 JOD',
   'No financial transaction',
  ]);
  expect(summary.totals['AED'],136);
  expect(summary.totals['SAR'],4.50);
  expect(summary.totals['JOD'],2.125);
  expect(summary.totals.length,3);
  expect(summary.unresolved,1);
 });

 test('M336 bulk SMS requires currency evidence BEFORE hash and finance commit',(){
  final app=File('lib/main.dart').readAsStringSync();
  final start=app.indexOf('Future<void> bulkSmsSheet(');
  final end=app.indexOf('Future<void> _previewForeignBankCurrency(',start);
  final bulk=app.substring(start,end);
  final marker=bulk.indexOf(
   'WaffraSmsCurrencies.requiresReviewForSarLedger(messages[index])');
  final hash=bulk.indexOf('final hash=bankSmsHash(messages[index]);',marker);
  final commit=bulk.indexOf('_financeAuthority.commitConfirmedSms(',hash);
  expect(marker,greaterThan(0));
  expect(hash,greaterThan(marker));
  expect(commit,greaterThan(hash));
  expect(bulk,contains('sourceTotalsLabel'));
 });

  test('M336 exchange approval cannot be forged by zero, NaN or unsupported',(){
  expect(WaffraCurrencyMinor.exact(0,'SAR'),isNull);
  expect(WaffraCurrencyMinor.exact(double.nan,'SAR'),isNull);
  expect(WaffraCurrencyMinor.exact(10,'ZZZ'),isNull);
  expect(WaffraCurrencyMinor.exact(9.999,'SAR'),isNull);
 });
}

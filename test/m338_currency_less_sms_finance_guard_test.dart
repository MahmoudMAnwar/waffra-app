import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
 test('M338 bare bank amounts cannot become unverified SAR ledger money',(){
  for(final message in <String>[
   'شراء PoS\nمبلغ: 120',
   'Incoming Transfer\nAmount: 30',
   'شراء PoS\nالمبلغ 120\nالرصيد: SAR 3000',
   'Card Purchase\nAmount 20\nAvailable balance: 100 SAR',
   'Card Purchase\nSAR 0\nBalance: 500 SAR',
   'شراء PoS\nSAR 0\nالرصيد ٥٠٠ SAR',
   'Card Purchase\nFee: SAR 1.50\nBalance: SAR 100.00',
  ]){
   final result=BankParser.parse(message);
   expect(result.amount,isNull,reason:message);
  }
 });
 test('M338 explicit SAR survives the strict bank amount guard',(){
  expect(BankParser.parse('شراء PoS\nبـSAR 20').amount,20);
  expect(BankParser.parse('شراء PoS\nبـ84.72SR').amount,84.72);
  expect(BankParser.parse('Incoming Transfer\nAmount: 30.25 SAR').amount,30.25);
 });
 test('M338 AED cannot be relabelled merely because app is Saudi',(){
  final foreign=BankParser.parse('Card Purchase\nAmount: 136 AED\nBalance: 4857 AED');
  expect(foreign.amount,isNull);
  expect(foreign.requiresCurrencyReview,isTrue);
 });
 test('M338 bank parser checks actual currency evidence after amount candidate',(){
  final code=File('lib/main.dart').readAsStringSync();
  final from=code.indexOf('class BankParser {');
  final end=code.indexOf('DateTime? bankSmsDate(',from);
  final segment=code.substring(from,end);
  expect(segment,contains("final verifiedSource=WaffraSmsCurrencies.originalAmount(s);"));
  expect(segment,contains("(verifiedSource.amount-value).abs()>0.00001"));
  expect(segment,contains("value=null;"));
 });
}

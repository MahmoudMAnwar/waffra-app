import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_amount_formatter.dart';
import 'package:waffra/waffra_validators.dart';

TextEditingValue formatted(WaffraAmountFormatter formatter,String input){
 return formatter.formatEditUpdate(const TextEditingValue(),
  TextEditingValue(text:input,selection:TextSelection.collapsed(offset:input.length)));
}

void main(){
 test('M302 default money validation remains strict to SAR halala precision',(){
  expect(formatted(const WaffraAmountFormatter(),'1234.567').text,'1,234.56');
  expect(WaffraValidators.positiveAmount('1,234.567'),'invalid_amount');
  expect(WaffraValidators.positiveAmount('0.00'),'invalid_amount');
  expect(WaffraValidators.positiveAmount('1,234.56'),isNull);
 });

 test('M302 configurable precision avoids silently cutting currency/commodity input',(){
  expect(formatted(const WaffraAmountFormatter(decimalPlaces:3),'1234.567').text,
      '1,234.567');
  expect(formatted(const WaffraAmountFormatter(decimalPlaces:4),'1234.5678').text,
      '1,234.5678');
  expect(formatted(const WaffraAmountFormatter(decimalPlaces:3),'١٢٣٤٫١٢٥').text,
      '1,234.125');
  expect(formatted(const WaffraAmountFormatter(decimalPlaces:4),'1234.567890').text,
      '1,234.5678');
 });

 test('M302 user-entered invalid signs and malformed grouping remain visible',(){
  for(final value in <String>['-123.456','1234..456','12,34.50','x123.50']){
   expect(formatted(const WaffraAmountFormatter(decimalPlaces:4),value).text,
       value,reason:'Invalid financial input must never become a different valid value');
  }
 });

 test('M302 identical category names cannot bypass Arabic search normalization',(){
  expect(WaffraValidators.uniqueCategory('ادخار',['إدخار']),'duplicate');
  expect(WaffraValidators.uniqueCategory('  مَصاريف  ',['مصاريف']),'duplicate');
  expect(WaffraValidators.uniqueCategory('صدقه',['صدقة']),'duplicate');
  expect(WaffraValidators.uniqueCategory('متجر اخر',['متجر آخر']),'duplicate');
  expect(WaffraValidators.uniqueCategory('Food',['FOOD']),'duplicate');
  expect(WaffraValidators.uniqueCategory('متجر جديد',['متجر آخر']),isNull);
  expect(WaffraValidators.uniqueCategory('   ',['ادخار']),'required');
 });

 test('M302 all three financial tools use precision-aware formatting',(){
  final converter=File('lib/currency_converter.dart').readAsStringSync();
  final gold=File('lib/waffra_gold_calculator.dart').readAsStringSync();
  final oil=File('lib/waffra_oil_market_section.dart').readAsStringSync();
  expect(converter,contains('WaffraAmountFormatter(decimalPlaces:3)'));
  expect(gold,contains('WaffraAmountFormatter(decimalPlaces:4)'));
  expect(oil,contains('WaffraAmountFormatter(decimalPlaces:3)'));
 });
}

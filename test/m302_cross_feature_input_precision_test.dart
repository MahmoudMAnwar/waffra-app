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

 test('M302 safely rejects misgrouped text in all financial tools',(){
  for(final ambiguous in [
    '1,2','1,23','12,34','1.234,50','1,234,56','1,,234',
    '-100','1e3','NaN','Infinity','1.2.3','1,234.5678'
  ]){
   expect(waffraStrictNumericInput(ambiguous,decimalPlaces:3),
     isNull,reason:'Never reinterpret '+ambiguous);
  }
  expect(waffraStrictNumericInput('1,234.567',decimalPlaces:3),1234.567);
  expect(waffraStrictNumericInput('١٬٢٣٤٫٥٦٧',decimalPlaces:3),1234.567);
  expect(waffraStrictNumericInput('۱۲۳۴٫۵۶',decimalPlaces:2),1234.56);
  expect(waffraStrictNumericInput('100.0001',decimalPlaces:3),isNull);
  expect(waffraStrictNumericInput('100.0001',decimalPlaces:4),100.0001);
  expect(waffraStrictNumericInput('0',decimalPlaces:3),isNull);
  expect(waffraStrictNumericInput('0',decimalPlaces:3,allowZero:true),0);
  expect(waffraStrictNumericInput('-120.25',allowNegative:true),-120.25);
  expect(waffraStrictNumericInput('-1,234.50',allowNegative:true),-1234.5);
  expect(waffraStrictNumericInput('-1,2',allowNegative:true),isNull);
  expect(waffraStrictNumericInput('-120.25'),isNull);
  expect(waffraStrictNumericInput('-1e3',allowNegative:true),isNull);

  expect(waffraStrictNumericInput('1000000.0001',decimalPlaces:4,
      maxValue:1000000),isNull);
 });

 test('M302 tool users must see overprecision rather than a changed amount',(){
  const currency=WaffraAmountFormatter(decimalPlaces:3,truncateExcess:false);
  const gold=WaffraAmountFormatter(decimalPlaces:4,truncateExcess:false);
  expect(formatted(currency,'123.4567').text,'123.4567');
  expect(formatted(gold,'123.45678').text,'123.45678');
  expect(waffraStrictNumericInput(formatted(currency,'123.4567').text,
      decimalPlaces:3),isNull);
  expect(waffraStrictNumericInput(formatted(gold,'123.45678').text,
      decimalPlaces:4),isNull);
 });
 
 test('M302 currency tool display uses 0, 2 or 3 ISO minor digits',(){
  for(final code in ['JPY','KRW']){
   expect(waffraCurrencyMinorDigits(code),0);
   expect(formatWaffraMoney(1234,decimalPlaces:waffraCurrencyMinorDigits(code)),'1,234');
  }
  for(final code in ['BHD','KWD','OMR','TND','JOD','IQD']){
   expect(waffraCurrencyMinorDigits(code),3);
   expect(formatWaffraMoney(198.125,decimalPlaces:waffraCurrencyMinorDigits(code)),'198.125');
  }
  for(final code in ['SAR','EGP','USD','EUR','GBP','AED','QAR','CAD']){
   expect(waffraCurrencyMinorDigits(code),2);
   expect(formatWaffraMoney(198.125,decimalPlaces:waffraCurrencyMinorDigits(code)),'198.13');
  }
  expect(formatWaffraMoney(1000),'1,000.00');
 });

 test('M302 finance inputs retain unrepresentable cents for field validation',(){
  const noTruncate=WaffraAmountFormatter(truncateExcess:false);
  final entered=formatted(noTruncate,'1234.567');
  expect(entered.text,'1234.567');
  expect(WaffraValidators.positiveAmount(entered.text),'invalid_amount');
  final main=File('lib/main.dart').readAsStringSync();
  final all=RegExp(r'inputFormatters:\[const WaffraAmountFormatter\(truncateExcess:false\)\]')
      .allMatches(main).length;
  expect(all,greaterThanOrEqualTo(10),
   reason:'Every live finance field must reject extra digits, not change them');
  expect(main,isNot(contains('inputFormatters:[const WaffraAmountFormatter()]')));
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
  final goldMarket=File('lib/waffra_gold_market_section.dart').readAsStringSync();
  final practical=File('lib/waffra_practical_tools_page.dart').readAsStringSync();

  expect(converter,contains('WaffraAmountFormatter(decimalPlaces:3,truncateExcess:false)'));
  expect(gold,contains('WaffraAmountFormatter(decimalPlaces:4,truncateExcess:false)'));
  expect(oil,contains('WaffraAmountFormatter(decimalPlaces:3,truncateExcess:false)'));
  expect(converter,contains('waffraStrictNumericInput(amount.text'));
  expect(gold,contains('waffraStrictNumericInput(weight.text'));
  expect(oil,contains('waffraStrictNumericInput(units.text'));
  expect(converter,contains('waffraCurrencyMinorDigits(to!)'));
  expect(gold,contains('waffraCurrencyMinorDigits(code)'));
  expect(oil,contains('waffraCountryCurrencies'));
  expect(oil,contains('waffraCurrencyMinorDigits(currency)'));
  expect(goldMarket,contains('waffraStrictNumericInput('));
  expect(goldMarket,contains('truncateExcess:false'));
  expect(practical,contains('waffraStrictNumericInput(source,'));
  expect(practical,contains('allowNegative:true'));

 });
}

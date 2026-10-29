import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_validators.dart';

void main() {
 group('M298 required category integrity', () {
  test('empty, whitespace, missing and stale categories never satisfy mandatory selection', () {
   const valid=['المطاعم / قهوة','الراتب','أخرى'];
   expect(WaffraValidators.requiredCategory(null,valid),'required');
   expect(WaffraValidators.requiredCategory('',valid),'required');
   expect(WaffraValidators.requiredCategory('  ',valid),'required');
   expect(WaffraValidators.requiredCategory('قسم محذوف',valid),'required');
   expect(WaffraValidators.requiredCategory('أخرى',const <String>[]),'required');
   expect(WaffraValidators.requiredCategory('الراتب',['أخرى']),'required');
   expect(WaffraValidators.requiredCategory('الراتب',valid),isNull);
   expect(WaffraValidators.requiredCategory('المطاعم / قهوة',valid),isNull);
  });

  test('income cannot reuse a category from expenses, and vice versa', () {
   final incomeCategories=['الراتب','حوالات واردة'];
   final expenseCategories=['المطاعم','تسوق'];
   expect(WaffraValidators.requiredCategory('الراتب',expenseCategories),'required');
   expect(WaffraValidators.requiredCategory('المطاعم',incomeCategories),'required');
   expect(WaffraValidators.requiredCategory('المطاعم',expenseCategories),isNull);
  });
 });

 group('M298 recurring day input', () {
  test('ASCII, Arabic and Persian numeric days normalize consistently', () {
   for(final day in ['1','01','31','٣١','١','۲۸','۰۱','۲۹']) {
    expect(WaffraValidators.dayOfMonth(day),isNull,reason:day);
   }
  });

  test('missing, zero, out-of-range and hidden suffixes are blocked', () {
   for(final day in ['', '  ', '0','00','32','٣٢','-1','1.5','1a','11x',' 2 8 ','200']) {
    expect(WaffraValidators.dayOfMonth(day),'invalid_day',reason:day);
   }
  });
 });

 test('M298 existing mandatory name and positive money validators remain strict', () {
  expect(WaffraValidators.requiredText('  '),'required');
  expect(WaffraValidators.requiredText(List.filled(101,'x').join()),'too_long');
  expect(WaffraValidators.positiveAmount(''),'required');
  expect(WaffraValidators.positiveAmount('0'),'invalid_amount');
  expect(WaffraValidators.positiveAmount('100.123'),'invalid_amount');
  expect(WaffraValidators.positiveAmount('1,250.00'),isNull);
  expect(WaffraValidators.positiveAmount('',required:false),isNull);
 });

 test('M298 all three finance entry points display category error and reject invalid selection',(){
  final source=File('lib/main.dart').readAsStringSync();
  expect(source,contains("labelText:waffraIsEnglish?'Message category *':'قسم هذه الرسالة *'"));
  expect(source,contains("labelText:waffraIsEnglish?'Category *':'القسم *'"));
  expect(source,contains("errorText:reviewAttempted&&WaffraValidators.requiredCategory("));
  expect(source,contains("errorText:attempted&&WaffraValidators.requiredCategory("));
  expect(source,contains("category:sms?chosen!:category"));
  expect(source,contains("category:selected,"));
  expect(source,contains("category=forType(v).isNotEmpty?forType(v).first.name:'';"));
  expect(source,contains("WaffraValidators.requiredCategory(selected,options.map((c)=>c.name))==null"));
  expect(source,contains("WaffraValidators.requiredCategory(category,available.map((c)=>c.name))!=null"));
 });
}

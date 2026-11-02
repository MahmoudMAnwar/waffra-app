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
  // M335 replaces the old flat category menu with required main/subcategory
  // pickers. Both the bulk SMS review and the shared manual/scan/SMS entry
  // sheet must reject an invalid (or stale) leaf before persisting money.
  expect(source,contains("labelText:waffraIsEnglish?'Main category *':'القسم الرئيسي *'"));
  expect(source,contains("labelText:waffraIsEnglish?'Subcategory *':'القسم الفرعي *'"));
  expect(source,contains("errorText:reviewAttempted&&activeSmsMains.isEmpty"));
  expect(source,contains("errorText:reviewAttempted&&"));
  expect(source,contains("!waffraCanAssignManualCategory(available,income,activeSmsParent,category)"));
  expect(source,contains("errorText:attempted&&selectedMain.isEmpty"));
  expect(source,contains("errorText:attempted&&selectedSub.isEmpty"));
  expect(source,contains("if(!waffraCanAssignManualCategory(categories,"));
  expect(source,contains("category:category,amount:n,"));
  expect(source,contains("category:selected,"));
  expect(source,contains("waffraIsEnglish?'Gender *':'الجنس *'"));
  expect(source,contains("waffraIsEnglish?'Attachment name *':'اسم المرفق *'"));
  expect(source,contains("waffraIsEnglish?'Phone number *':'رقم الجوال *'"));
  expect(source,contains("waffraIsEnglish?'Password *':'كلمة المرور *'"));
  expect(source,contains("WaffraValidators.requiredCategory(selected,validNames)==null"));
 });
}

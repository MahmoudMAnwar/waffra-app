import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_i18n.dart';

void main() {
 setUp(() => waffraLanguage.value='ar');
 tearDown(() => waffraLanguage.value='ar');

 test('Arabic mandatory errors are consistent for all form field types', () {
  expect(waffraTextFieldError(''), 'هذا الحقل مطلوب');
  expect(waffraTextFieldError('   '), 'هذا الحقل مطلوب');
  expect(waffraAmountFieldError(''), 'هذا الحقل مطلوب');
  expect(waffraAmountFieldError('   '), 'هذا الحقل مطلوب');
  expect(waffraMobileFieldError(''), 'هذا الحقل مطلوب');
  expect(waffraPasswordFieldError(''), 'هذا الحقل مطلوب');
  expect(waffraConfirmPasswordFieldError('', 'Strong123'), 'هذا الحقل مطلوب');
  expect(waffraDayFieldError(''), 'هذا الحقل مطلوب');
  expect(waffraPinFieldError(''), 'هذا الحقل مطلوب');
 });

 test('Invalid or mismatched values show a specific field-level error', () {
  expect(waffraMobileFieldError('0412345678'), contains('05'));
  expect(waffraPasswordFieldError('abc'), contains('8'));
  expect(waffraConfirmPasswordFieldError('Different123','Valid123'), 'كلمتا المرور غير متطابقتين');
  expect(waffraDayFieldError('32'), contains('31'));
  expect(waffraAmountFieldError('0'), isNot('هذا الحقل مطلوب'));
  expect(waffraAmountFieldError('-1'), isNotNull);
  expect(waffraAmountFieldError('abc'), isNotNull);
  expect(waffraPinFieldError('123'), contains('أربعة'));
  expect(waffraTextFieldError('x'.padRight(101,'x')), contains('الحد الأقصى'));
 });

 test('Correct values clear the validation error', () {
  expect(waffraTextFieldError('قسم جديد'), isNull);
  expect(waffraAmountFieldError('1,200.50'), isNull);
  expect(waffraAmountFieldError('',required:false), isNull);
  expect(waffraMobileFieldError('0512345678'), isNull);
  expect(waffraPasswordFieldError('Valid123'), isNull);
  expect(waffraConfirmPasswordFieldError('Valid123','Valid123'), isNull);
  expect(waffraDayFieldError('31'), isNull);
  expect(waffraPinFieldError('1234'), isNull);
  expect(waffraPinFieldError('12345678',existing:true), isNull);
 });

 test('English errors are localized and distinguish empty from malformed', () {
  waffraLanguage.value='en';
  expect(waffraTextFieldError(''), 'This field is required');
  expect(waffraMobileFieldError(''), 'This field is required');
  expect(waffraAmountFieldError(''), 'This field is required');
  expect(waffraDayFieldError(''), 'This field is required');
  expect(waffraPasswordFieldError(''), 'This field is required');
  expect(waffraConfirmPasswordFieldError('', 'Pass1234'), 'This field is required');
  expect(waffraAmountFieldError('0'), 'Enter an amount greater than zero');
  expect(waffraConfirmPasswordFieldError('Different123','Pass1234'), 'Passwords do not match');
 });

 testWidgets('An invalid mandatory field displays its message under the input', (tester) async {
  await tester.pumpWidget(MaterialApp(
   theme:ThemeData(inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder())),
   home:Scaffold(body:TextField(decoration:InputDecoration(
    labelText:'اسم القسم *',errorText:waffraTextFieldError('')))),
  ));
  expect(find.byType(TextField), findsOneWidget);
  expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
 });
}

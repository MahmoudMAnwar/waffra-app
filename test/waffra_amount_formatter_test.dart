import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_amount_formatter.dart';

void main() {
 test('displays grouped money with two fractional digits', () {
  expect(formatWaffraMoney(1000), '1,000.00');
  expect(formatWaffraMoney(10000), '10,000.00');
  expect(formatWaffraMoney(12500.5), '12,500.50');
  expect(formatWaffraMoney(1000000), '1,000,000.00');
 });
 test('adds thousands separators as users type', () {
  const formatter=WaffraAmountFormatter();
  const empty=TextEditingValue();
  final v=formatter.formatEditUpdate(empty,
   const TextEditingValue(text:'10000',selection:TextSelection.collapsed(offset:5)));
  expect(v.text,'10,000');
  expect(v.selection.baseOffset,6);
 });
 test('keeps decimal input and supports Arabic digits', () {
  const formatter=WaffraAmountFormatter();
  const empty=TextEditingValue();
  final decimal=formatter.formatEditUpdate(empty,
   const TextEditingValue(text:'10000.50',selection:TextSelection.collapsed(offset:8)));
  expect(decimal.text,'10,000.50');
  final arabic=formatter.formatEditUpdate(empty,
   const TextEditingValue(text:'١٠٬٠٠٠٫٥٠',selection:TextSelection.collapsed(offset:9)));
  expect(arabic.text,'10,000.50');
 });
 test('pasted invalid values remain visible and fail shared validation', () {
  const formatter=WaffraAmountFormatter();
  const empty=TextEditingValue();
  for(final value in ['-100','12a','1e3','1,2','1.2.3']) {
   final rendered=formatter.formatEditUpdate(empty,
    TextEditingValue(text:value,
      selection:TextSelection.collapsed(offset:value.length)));
   expect(rendered.text,value,
    reason:'invalid money must never silently change its numeric meaning');
  }
 });
 test('limits fractional precision to two digits', () {
  const formatter=WaffraAmountFormatter();
  const empty=TextEditingValue();
  final v=formatter.formatEditUpdate(empty,
   const TextEditingValue(text:'1234.5678',selection:TextSelection.collapsed(offset:9)));
  expect(v.text,'1,234.56');
 });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_amount_formatter.dart';
import 'package:waffra/waffra_validators.dart';

TextEditingValue typeNumber(String value) {
 const formatter = WaffraAmountFormatter(truncateExcess:false);
 var current=const TextEditingValue();
 for (final character in value.split('')) {
  final next=TextEditingValue(
   text:current.text.replaceRange(
    current.selection.extentOffset,current.selection.extentOffset,character),
   selection:TextSelection.collapsed(offset:current.selection.extentOffset+1));
  current=formatter.formatEditUpdate(current,next);
 }
 return current;
}

void main() {
 test('M361 13500 is accepted from first incremental entry',(){
  final entered=typeNumber('13500');
  expect(entered.text,'13,500');
  expect(entered.selection.extentOffset,6);
  expect(WaffraValidators.positiveAmount(entered.text),isNull);
 });

 test('M361 1350000 and decimal cents preserve numeric meaning',(){
  final entered=typeNumber('1350000');
  expect(entered.text,'1,350,000');
  expect(entered.selection.extentOffset,9);
  expect(WaffraValidators.positiveAmount(entered.text),isNull);
  expect(typeNumber('13500.25').text,'13,500.25');
 });

 test('M361 Arabic and Persian digits are normalized during typing',(){
  expect(typeNumber('١٣٥٠٠').text,'13,500');
  expect(typeNumber('۱۳۵۰۰').text,'13,500');
 });

 test('M361 malformed pasted separators remain invalid',(){
  const formatter=WaffraAmountFormatter(truncateExcess:false);
  for(final pasted in ['1,23','1,2345','1,,234','-13500','1e5']){
   final edited=formatter.formatEditUpdate(const TextEditingValue(),
    TextEditingValue(text:pasted,
     selection:TextSelection.collapsed(offset:pasted.length)));
   expect(edited.text,pasted);
   expect(WaffraValidators.positiveAmount(edited.text),isNotNull);
  }
 });
}

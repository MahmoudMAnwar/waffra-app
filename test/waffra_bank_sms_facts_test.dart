import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';

void main(){
 test('outgoing wallet transfer stays a transfer, not an expense',(){
  final sms='عملية حوالة مالية صادرة مقبولة\n'
   'خصمت من محفظة: **8308\n'
   'إلى: TEST RECIPIENT\n'
   'أيبان: **9288\n'
   'القيمة: SAR 882\n'
   'الرسوم: SAR 0.58\n'
   'في: 02-11-2026 15:13\n'
   'الرقم المرجعي: DEMO1234TEST';
  final item=WaffraBankSmsFactsParser.parse(sms);
  expect(item.kind,WaffraBankOperationKind.transfer);
  expect(item.canAutoPostAsIncomeExpense,isFalse);
  expect(item.sourceSuffix,'8308');
  expect(item.destinationSuffix,'9288');
  expect(item.fee,0.58);
  expect(item.reference,'DEMO1234TEST');
 });
 test('credit transfer is a transfer even though incoming',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Credit Transfer via Alinma Bank\nAmount: SAR 1900.00');
  expect(item.kind,WaffraBankOperationKind.transfer);
  expect(item.canAutoPostAsIncomeExpense,isFalse);
 });
 test('cashback refund is true income',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Refund Received\nAmount: SAR 50.00');
  expect(item.kind,WaffraBankOperationKind.income);
  expect(item.canAutoPostAsIncomeExpense,isTrue);
 });
 test('purchase is expense',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Card Purchase SAR 75.00 TEST FUEL STATION');
  expect(item.kind,WaffraBankOperationKind.expense);
  expect(item.canAutoPostAsIncomeExpense,isTrue);
 });
 test('card settlement never posts as purchase',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Credit Card Payment amount SAR 200');
  expect(item.kind,WaffraBankOperationKind.cardSettlement);
  expect(item.canAutoPostAsIncomeExpense,isFalse);
 });
 test('unknown SMS is uncertain',(){
  final item=WaffraBankSmsFactsParser.parse('Hello, your appointment is tomorrow');
  expect(item.kind,WaffraBankOperationKind.uncertain);
  expect(item.canAutoPostAsIncomeExpense,isFalse);
 });
 test('declined purchase cannot post',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Card Purchase declined SAR 42.50');
  expect(item.pending,isTrue);
  expect(item.canAutoPostAsIncomeExpense,isFalse);
 });
 test('sender account suffix is not inferred from any random number',(){
  final item=WaffraBankSmsFactsParser.parse(
   'Card Purchase SAR 15.00 merchant TEST counter 123456');
  expect(item.sourceSuffix,isNull);
  expect(item.destinationSuffix,isNull);
 });
}

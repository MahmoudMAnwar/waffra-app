import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_receipt_ocr_parser.dart';

void main(){
 const fourBankSms='''AlRajhiBank
شراء PoS
عبر:7678-مدى
SAR 33.00
COMANY AL
29/10/26 17:07
شراء PoS
عبر:7678-مدى
SAR 4.00
COMANY AL
29/10/26 17:08
شراء PoS
عبر:7678-مدى
SAR 4.50
Joanna Sa
30/10/26 23:49
شراء PoS
عبر:7678-مدى
SAR 10.00
Joanna Sa
30/10/26 00:01''';

 test('M297 four bank bubbles produce four independent expense drafts',(){
  final candidates=WaffraBankScreenshotParser.candidates(fourBankSms);
  expect(candidates.length,4);
  expect(candidates.map((c)=>c.amount).toList(),[33,4,4.5,10]);
  expect(candidates.every((c)=>!c.income),isTrue);
  expect(candidates[0].merchant,'COMANY AL');
  expect(candidates[2].merchant,'Joanna Sa');
  expect(candidates[0].date,DateTime(2026,10,29));
  expect(candidates[2].date,DateTime(2026,10,30));
 });

 test('M297 bank screenshots do not prefill one fabricated receipt',(){
  final guessed=WaffraReceiptOcrParser.parse(fourBankSms);
  expect(guessed.amount,isNull);
  expect(guessed.merchant,isNull);
  expect(guessed.date,isNull);
  expect(guessed.rawText,contains('SAR 33.00'));
 });

 test('M297 card IDs, available balances and footer chrome are excluded',(){
  const raw='''AlRajhiBank
شراء POS
رقم البطاقة 54077678
الرصيد SAR 2500.00
عبر:7678-مدى
SAR 33.00
Coffee Shop
29/10/26 17:07
Sender can't accept replies. Contact them directly.''';
  final rows=WaffraBankScreenshotParser.candidates(raw);
  expect(rows.length,1);
  expect(rows.single.amount,33);
  expect(rows.single.merchant,'Coffee Shop');
  expect(rows.single.sourceText,contains('54077678'));
  expect(rows.single.amount,isNot(54077678));
 });

 test('M297 no currency, malformed cents or large card-like numbers abstain',(){
  for(final raw in [
   'شراء POS\nعبر:7678\n54077678\n29/10/26',
   'شراء POS\nSAR 54077678\n29/10/26',
   'شراء POS\nSAR 4.505\n29/10/26',
   'شراء POS\nSAR 33.00\nSAR 45.00\n29/10/26',
  ]){
   expect(WaffraBankScreenshotParser.candidates(raw),isEmpty,reason:raw);
  }
 });

 test('M297 income transfer is offered as income, always for human review',(){
  final rows=WaffraBankScreenshotParser.candidates(
   'تحويل وارد\nSAR 620.50\nمن جهة العمل\n29/10/26');
  expect(rows.length,1);
  expect(rows.single.amount,620.5);
  expect(rows.single.income,isTrue);
 });

 test('M297 ordinary receipt still extracts labeled total',(){
  final receipt=WaffraReceiptOcrParser.parse(
    'Corner Coffee\nTax invoice\nDate: 2026-10-27\nTotal SAR 42.75');
  expect(receipt.merchant,'Corner Coffee');
  expect(receipt.amount,42.75);
  final unlabeled=WaffraReceiptOcrParser.parse('Store\n54077678\n29/10/26');
  expect(unlabeled.amount,isNull);
 });

 test('M297 full home add flow has three actions and uses guarded entry form',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains("'Manual transaction':'عملية يدوية'"));
  expect(src,contains("'Bank message':'رسالة بنكية'"));
  expect(src,contains("'Scan receipt / image':'تصوير / استخراج فاتورة'"));
  expect(src,contains('_launchAddAction(scanAndAddReceipt,fromMenu:true)'));
  expect(src,contains('()=>WaffraReceiptOcr.scan(picked.path)'));
  expect(src,contains('waffra-ai-analysis-progress'));
  expect(src,contains('await entrySheet('));
  expect(src,contains('scannedReceipt:'));
  expect(src,contains('scannedIncome:'));
  expect(src,contains('scannedImage:picked'));
  expect(src,contains("sourceType:initial?.sourceType??(sms?'sms':scannedReceipt!=null?'receipt':'manual')"));
 });

 test('M297 bank SMS buttons share a responsive horizontal row',(){
  final src=File('lib/main.dart').readAsStringSync();
  expect(src,contains("Key('waffra-sms-paste-action')"));
  expect(src,contains("Key('waffra-sms-open-messages-action')"));
  expect(src,contains('return stack?Column('));
  expect(src,contains('Expanded(child:pasteAction)'));
  expect(src,contains('Expanded(child:messagesAction)'));
  expect(src,contains('constraints.maxWidth<318'));
 });
}

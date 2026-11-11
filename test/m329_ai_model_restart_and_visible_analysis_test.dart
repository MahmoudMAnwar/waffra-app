import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final home=File('lib/main.dart').readAsStringSync();
 test('M636 OCR progress remains bounded and dismisses on completion',(){
  expect(home,contains("Key('waffra-ocr-analysis-progress')"));
  expect(home,contains('item.remove();'));
  expect(home,contains('item.dispose();'));
  expect(home,contains('()=>WaffraReceiptOcr.scan(picked.path)'));
  expect(home,contains('WaffraBankScreenshotParser.reviewItems(extracted.rawText)'));
 });
 test('M636 offline review never needs deleted GGUF',(){
  expect(home,isNot(contains('WaffraOnDeviceQwen.shared')));
  expect(home,isNot(contains('WaffraAiFinanceBrain.imageOcr(')));
  expect(home,contains('if(!WaffraSaudiRelease.receiptImageTransactionImport){'));
  expect(home,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
 });
}

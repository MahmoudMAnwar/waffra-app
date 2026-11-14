import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final home=readWaffraMainSourceForContracts();
 test('M636 plus offers manual entry, not bank-message paste',(){
  expect(home,contains("label:waffraIsEnglish?'Add manual transaction':'إضافة عملية يدوية'"));
  expect(home,contains('unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true))'));
  expect(home,isNot(contains('unawaited(_launchAddAction(()=>bulkSmsSheet()')));
  expect(home,isNot(contains('Future<void> bulkSmsSheet(')));
 });
 test('M640 no old OCR scan button or model survives',(){
  expect(home,isNot(contains('Future<void> scanAndAddReceipt()async')));
  expect(home,isNot(contains('WaffraReceiptOcr.scan(picked.path)')));
  expect(home,isNot(contains('WaffraBankScreenshotParser.reviewItems(extracted.rawText)')));
  expect(home,isNot(contains('WaffraOnDeviceQwen')));
 });
 test('M636 auto SMS remains reviewed, account-bound, and explicitly saved',(){
  expect(home,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
  expect(home,contains('await WaffraAutoSms.acknowledgeCommitted([id]);'));
  expect(home,contains('waffraCanAssignManualCategory('));
 });
}

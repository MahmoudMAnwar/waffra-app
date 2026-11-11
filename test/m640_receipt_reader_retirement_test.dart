import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_practical_tools_page.dart';

/// M640 / #561 — owner's complete receipt OCR retirement, not UI hiding.
void main(){
 test('M640 Tesseract runtime, scanner parsers and active OCR CI are deleted',(){
  for(final path in <String>[
   'lib/waffra_receipt_ocr.dart',
   'lib/waffra_receipt_ocr_parser.dart',
   'lib/waffra_bank_screenshot_parser.dart',
   'scripts/qa/m287_patch_tesseract_gradle.py',
   '.github/workflows/m287-receipt-ocr.yml',
   '.github/workflows/m297-receipt-to-entry.yml',
  ]){
   expect(File(path).existsSync(),isFalse,reason:path);
  }
  final pubspec=File('pubspec.yaml').readAsStringSync();
  expect(pubspec,isNot(contains('flutter_tesseract_ocr')));
  // An ordinary photo attachment is a user-controlled encrypted receipt,
  // not image recognition; do NOT remove the picker or receipt storage.
  expect(pubspec,contains('image_picker:'));
  expect(File('lib/storage/waffra_verified_receipt_screen_gateway.dart').existsSync(),isTrue);
  expect(File('lib/storage/waffra_encrypted_receipt_vault.dart').existsSync(),isTrue);
  expect(File('lib/storage/waffra_verified_encrypted_finance_bridge.dart').existsSync(),isTrue);
 });

 test('M640 all former scan-and-create paths, flags and model fetches are gone',(){
  final app=File('lib/main.dart').readAsStringSync();
  final tools=File('lib/waffra_practical_tools_page.dart').readAsStringSync();
  final brain=File('lib/waffra_ai_finance_brain.dart').readAsStringSync();
  final release=File('lib/waffra_saudi_release.dart').readAsStringSync();
  for(final source in [app,tools,brain,release]){
   for(final forbidden in <String>[
    'WaffraReceiptOcr','WaffraReceiptOcrParser','WaffraBankScreenshotParser',
    'scanAndAddReceipt','receiptImageTransactionImport',
    'flutter_tesseract_ocr','m287-ocr','receiptAssistant()',
    'WaffraAiFinanceBrain.imageOcr',
   ]){
    expect(source,isNot(contains(forbidden)),reason:forbidden);
   }
  }
  expect(app,isNot(contains('waffra-ocr-analysis-progress')));
  expect(app,isNot(contains('scannedReceipt')));
  expect(app,isNot(contains('scannedImage')));
  expect(app,isNot(contains('sourceType:initial?.sourceType??(sms?\'sms\':scannedReceipt')));
  expect(app,contains('Future<void> entrySheet('));
  expect(app,contains('ImagePicker().pickImage(source:ImageSource.camera'));
  expect(brain,contains('static Future<WaffraAiResult> bankSms('));
  expect(tools,contains("section(2, 'الإقفال الشهري'"));
  expect(tools,contains("section(3, 'تشخيص الأعطال الآمن'"));
  expect(tools,contains('List.generate(4, (_) => GlobalKey())'));
  expect(tools,isNot(contains('قارئ الفواتير OCR')));
 });

 test('M640 no active workflow calls the removed native OCR shim',(){
  final workflows=Directory('.github/workflows').listSync()
   .whereType<File>().where((f)=>f.path.endsWith('.yml')||f.path.endsWith('.yaml'));
  for(final wf in workflows){
   final text=wf.readAsStringSync();
   expect(text,isNot(contains('m287_patch_tesseract_gradle')),
     reason:wf.path);
   expect(text,isNot(contains('flutter_tesseract_ocr')),
     reason:wf.path);
   expect(text,isNot(contains('SwiftyTesseract')),
     reason:wf.path);
  }
 });

 for(final english in <bool>[false,true]){
  testWidgets('M640 only four practical Tools sections remain / ${english?'EN':'AR'}',(tester)async{
   await tester.pumpWidget(MaterialApp(home:WaffraPracticalToolsPage(
    english:english,entries:const [],
   )));
   await tester.pumpAndSettle();
   for(final key in [
    'm281-health-tile','m281-search-tile','m281-month-tile','m281-diagnostics-tile',
   ]){
    expect(find.byKey(Key(key)),findsOneWidget);
   }
   expect(find.byKey(const Key('m281-receipt-tile')),findsNothing);
   expect(find.textContaining('Receipt OCR scanner'),findsNothing);
   expect(find.textContaining('قارئ الفواتير'),findsNothing);
  });
 }
}

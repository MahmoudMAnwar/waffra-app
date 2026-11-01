import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home=File('lib/main.dart').readAsStringSync();
  final gate=File('lib/waffra_ai_model_gate.dart').readAsStringSync();

  test('M335 bank paste and Android shares open without initializing Qwen',(){
    final entry=home.indexOf('Future<void> bulkSmsSheet({String? initialText})async');
    final sheet=home.indexOf('_smsSheetOpen=true;',entry);
    final pasted=home.indexOf('final pasted=TextEditingController',sheet);
    expect(entry,greaterThan(0));
    expect(sheet,greaterThan(entry));
    expect(pasted,greaterThan(sheet));
    expect(home.substring(entry,pasted),isNot(contains('await _requireBankSmsAi()')));
    expect(home,contains('unawaited(bulkSmsSheet(initialText:text))'));
    expect(home,contains('unawaited(_launchAddAction(()=>bulkSmsSheet(),fromMenu:true))'));
  });

  test('M335 offline OCR opens camera and reviews without GGUF',(){
    final start=home.indexOf('Future<void> scanAndAddReceipt()async');
    final camera=home.indexOf('ImageSource.camera',start);
    final scan=home.indexOf('WaffraReceiptOcr.scan(picked.path)',camera);
    final candidates=home.indexOf('WaffraBankScreenshotParser.reviewItems(extracted.rawText)',scan);
    expect(start,greaterThan(0));
    expect(camera,greaterThan(start));
    expect(scan,greaterThan(camera));
    expect(candidates,greaterThan(scan));
    expect(home.substring(start,camera),isNot(contains('_requireReceiptOcrAi()')));
    expect(home,contains('!extracted.hasSuggestions&&'));
    expect(home,contains('_receiptOcrAiOpening=false;'));
  });

  test('M335 AI download still requires opt-in for Ask Waffra',(){
    expect(gate,contains('static Future<bool> requireForFeature('));
    expect(gate,contains('waffra-ai-first-use-consent'));
    expect(gate,contains('manual entry still works'));
    expect(gate,contains('الإضافة اليدوية متاحة'));
    expect(home,contains('unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true))'));
  });

  test('M335 deletion cannot suppress deterministic review or bypass writer',(){
    final save=home.indexOf('Future<void> saveParsedMessages(');
    final parse=home.indexOf('final found=splitBankMessages',save);
    expect(save,greaterThan(0));
    expect(parse,greaterThan(save));
    expect(home.substring(save,parse),isNot(contains('if(!WaffraOnDeviceQwen.shared.isReady)')));
    expect(home,contains('if(results[i].amount==null||results[i].amount!<=0)'));
    expect(home,contains('WaffraSmsCurrencies.summarize(found)'));
    expect(home,contains('waffraCanAssignManualCategory('));
  });
}

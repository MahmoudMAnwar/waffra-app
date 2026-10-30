import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home=File('lib/main.dart').readAsStringSync();
  final gate=File('lib/waffra_ai_model_gate.dart').readAsStringSync();

  test('M324: bank message and Android share routes require local AI first',(){
    final entry=home.indexOf('Future<void> bulkSmsSheet({String? initialText})async');
    final approval=home.indexOf('try{allowed=await _requireBankSmsAi();}',entry);
    final blocked=home.indexOf('if(!allowed||!mounted||_smsSheetOpen)return;',approval);
    final sheet=home.indexOf('_smsSheetOpen=true;',blocked);
    final paste=home.indexOf('final pasted=TextEditingController',sheet);
    expect(entry,greaterThan(0));
    expect(approval,greaterThan(entry));
    expect(blocked,greaterThan(approval));
    expect(sheet,greaterThan(blocked));
    expect(paste,greaterThan(sheet));
    expect(home,contains('unawaited(bulkSmsSheet(initialText:text))'));
    expect(home,contains('unawaited(_launchAddAction(()=>bulkSmsSheet(),fromMenu:true))'));
    expect(home,contains('if(_smsSheetOpen||_bankSmsAiOpening)return;'));
  });

  test('M324: receipt OCR requires local model BEFORE camera/gallery',(){
    final start=home.indexOf('Future<void> scanAndAddReceipt()async');
    final gateCall=home.indexOf('try{allowed=await _requireReceiptOcrAi();}',start);
    final blocked=home.indexOf('if(!allowed||!mounted)return;',gateCall);
    final camera=home.indexOf('ImageSource.camera',blocked);
    final scan=home.indexOf('WaffraReceiptOcr.scan(picked.path)',camera);
    expect(start,greaterThan(0));
    expect(gateCall,greaterThan(start));
    expect(blocked,greaterThan(gateCall));
    expect(camera,greaterThan(blocked));
    expect(scan,greaterThan(camera));
    expect(home,contains('if(!WaffraOnDeviceQwen.shared.isReady){'));
  });

  test('M324: cancellation explains feature is locked, preserving manual entry',(){
    expect(gate,contains('static Future<bool> requireForFeature('));
    expect(gate,contains('return context.mounted&&ready&&WaffraOnDeviceQwen.shared.isReady;'));
    expect(gate,isNot(contains('waffra-ai-required-feature-notice')));
    expect(gate,contains('manual entry still works'));
    expect(gate,contains('الإضافة اليدوية متاحة'));
    expect(gate,contains('waffra-ai-first-use-consent'));
    expect(gate,contains('return false;'));
    expect(home,contains("featureAr:'تحليل الرسائل البنكية'"));
    expect(home,contains("featureEn:'receipt and image OCR scanning'"));
    expect(home,contains('if(initial==null&&(sms||scannedReceipt!=null||scannedImage!=null))'));
    expect(home,contains('unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true))'));
  });

  test('M324: deletion blocks SMS saves while retaining existing ledger',(){
    final save=home.indexOf('Future<void> saveParsedMessages(');
    final localGuard=home.indexOf('if(!WaffraOnDeviceQwen.shared.isReady){',save);
    final savePath=home.indexOf('final found=splitBankMessages',save);
    expect(save,greaterThan(0));
    expect(localGuard,greaterThan(save));
    expect(savePath,greaterThan(localGuard));
    expect(home,contains('Bank-message importing and image OCR scanning'));
    expect(home,contains('معاملاتك وفواتيرك ونسخك الاحتياطية'));
  });
}

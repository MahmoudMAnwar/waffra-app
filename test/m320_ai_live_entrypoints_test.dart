import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final home=File('lib/main.dart').readAsStringSync();
 final tools=File('lib/waffra_smart_features.dart').readAsStringSync();
 test('M636 retired model has no executable entry point or installer',(){
  expect(File('lib/waffra_ondevice_qwen.dart').existsSync(),isFalse);
  expect(File('lib/waffra_ai_model_gate.dart').existsSync(),isFalse);
  expect(File('pubspec.yaml').readAsStringSync(),isNot(contains('llamadart:')));
  for(final text in [home,tools]){
   expect(text,isNot(contains('WaffraOnDeviceQwen')));
   expect(text,isNot(contains('WaffraAiModelGate')));
  }
  expect(tools,isNot(contains('waffra-local-ai-opt-in')));
  expect(tools,isNot(contains('waffra-m268-feature-assistant')));
 });
 test('M636 secure logout drains finance before clearing owner',(){
  expect(home,contains('await closingHome._m627CloseForLogout();'));
  expect(home,contains('await closeHomeFinance();'));
  expect(home.indexOf('await closeHomeFinance();'),
   lessThan(home.indexOf('await _accountWriteAuthority.signOut();')));
  expect(home,contains('WaffraAutoSms.suspendForSignOut()'));
 });
 test('M636 automatic SMS review still demands verified human editor',(){
  expect(home,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
  expect(home,contains('await WaffraAutoSms.acknowledgeCommitted([id]);'));
  expect(home,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(home,contains('Future<void> _m565ConfirmSms('));
  expect(home,isNot(contains('Future<void> bulkSmsSheet(')));
 });
}

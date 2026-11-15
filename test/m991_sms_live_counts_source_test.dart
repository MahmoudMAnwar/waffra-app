import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M991 currently open sender sheet reacts to verified queue revision',(){
  final inbox=File('lib/waffra_home_sms_inbox.part.dart').readAsStringSync();
  expect(inbox,contains('ValueListenableBuilder<int>('));
  expect(inbox,contains('valueListenable:_m991SmsReviewRevision'));
  expect(inbox,contains('revision!=renderedRevision'));
  expect(inbox,contains('bySender..clear()..addAll(fresh.bySender)'));
  expect(inbox,contains('senders..clear()..addAll(fresh.senders)'));
  expect(inbox,contains('rebuildCalendarIndex();'));
  expect(inbox,contains('refreshReviewIds();'));
  expect(inbox,contains('selectedIds.removeWhere('));
  expect(inbox,contains('!senders.contains(selectedSender)'));
  expect(inbox,isNot(contains('importMonth:true')));
 });
 test('M991 only owner-verified native pending rows and rule delta enter cache',(){
  final refresh=File('lib/waffra_home_sms_refresh.part.dart').readAsStringSync();
  final main=File('lib/main.dart').readAsStringSync();
  expect(refresh,contains('final results=await WaffraAutoSms.pendingChecked();'));
  expect(refresh,contains('_m991CachedSmsOwner==_smsRuleOwnerKey'));
  expect(refresh,contains('_m991CachedCategorySignature==signature'));
  expect(refresh,contains("'previousRules':canReuse?"));
  expect(refresh,contains("'cached':canReuse?"));
  expect(refresh,contains('_m991SmsReviewRevision.value++;'));
  expect(main,contains('WaffraSmsIncrementalRuleReview.canReuse('));
  expect(main,contains('if(hashes.contains(bankSmsHash(body)))'));
  expect(main,contains('WaffraBankSmsFactsParser.isVerificationChallenge(body)'));
  expect(main,contains("annotated['multipleEvents']=true"));
  expect(main,contains("if(local['kind']=='excluded')"));
  expect(main,contains("'m991Evaluated'"));
  expect(refresh,isNot(contains('saveCaptured(')));
 });
}

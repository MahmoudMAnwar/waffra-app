import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 final source=File('lib/main.dart').readAsStringSync();

 test('M470 #3/#4: manual and SMS success paths parse outside UI isolate',(){
  final sms=source.substring(
   source.indexOf(' Future<void> bulkSmsSheet('),
   source.indexOf(' Future<void> entrySheet('));
  expect(sms,contains('await WaffraLargeJsonDecode.parse('));
  expect(sms,contains('final persistedRaw=await WaffraLargeJsonDecode.parse('));
  expect(sms,contains('final decodedCategories=await WaffraLargeJsonDecode.parse(stored);'));
  expect(sms.indexOf('final decodedCategories=await WaffraLargeJsonDecode.parse(stored);'),
   lessThan(sms.indexOf('if(verifiedCategories!=null){')));
  final manual=source.substring(
   source.indexOf(' Future<void> entrySheet('),
   source.indexOf(' Future<void> showReceipt('));
  expect(manual,contains('final decoded=await WaffraLargeJsonDecode.parse(raw);'));
  expect(manual,contains('final parsedLedger=await WaffraLargeJsonDecode.parse('));
  expect(manual,contains('if(decoded is! List)throw StateError'));
  expect(manual,contains('if(parsedLedger is! List)throw StateError'));
 });

 test('M470 final UX: no Teach Waffra, post-confirmed-only safe learning',(){
  final review=source.substring(
   source.indexOf(' Future<void> _reviewAutoSmsCandidates('),
   source.indexOf(' void _receiveSharedSms('));
  expect(review,isNot(contains('waffra-sms-teach-action')));
  expect(review,isNot(contains("decision=='teach'")));
  expect(review,isNot(contains('await _openSmsRules(')));
  expect(review,isNot(contains('resumeAfterTeachId')));
  expect(review,contains("decision=='transfer'&&mounted"));
  expect(review,contains('await _reviewSmsAccountTransfer(item:selected,facts:facts);'));
  expect(review,contains('final acknowledged=await WaffraAutoSms.acknowledge([id]);'));
  final reviewAction=review.indexOf("decision=='review'&&mounted");
  final confirmed=review.indexOf('if(smsHashes.contains(bankSmsHash(body)))',reviewAction);
  final rule=review.indexOf('await _learnSafeSmsRule(',confirmed);
  expect(confirmed,greaterThan(reviewAction));
  expect(rule,greaterThan(confirmed));
  // An unsafe keyword never forces the editor after a valid financial save.
  expect(review,contains('if(learned&&mounted){'));
  final transfer=source.substring(
   source.indexOf(' Future<void> _reviewSmsAccountTransfer('),
   source.indexOf(' Future<void> _reviewAutoSmsCandidates('));
  expect(transfer.indexOf('try{await _learnSafeSmsRule('),
   greaterThan(transfer.indexOf('if(!mounted||!saved)return;')));
  final settings=source.substring(
   source.indexOf(' Future<void> _openSmsRules('),
   source.indexOf(' Future<void> _recordConfirmedSmsAccountAssociation('));
  expect(settings,contains('WaffraSmsRuleSettingsPage('));
 });
}

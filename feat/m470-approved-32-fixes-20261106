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

 test('M470 #14: Teach Waffra back returns to the same pending SMS',(){
  final rules=source.substring(
   source.indexOf(' Future<void> _openSmsRules('),
   source.indexOf(' Future<void> _recordConfirmedSmsAccountAssociation('));
  expect(rules,contains('final ruleSaved=await Navigator.push<bool>('));
  expect(rules,contains('if(mounted&&ruleSaved==true)unawaited('));
  final review=source.substring(
   source.indexOf(' Future<void> _reviewAutoSmsCandidates('),
   source.indexOf(' void _receiveSharedSms('));
  expect(review,contains('String? resumeAfterTeachId;'));
  expect(review,contains("decision=='teach'"));
  expect(review,contains('resumeAfterTeachId=id;'));
  expect(review,contains('WidgetsBinding.instance.addPostFrameCallback'));
  expect(review,contains('unawaited(_reviewAutoSmsCandidates(targetId:target));'));
  expect(review,contains('if(!mounted||selected==null)return;'));
  expect(review,contains('if(smsHashes.contains(bankSmsHash(body)))'));
 });
}

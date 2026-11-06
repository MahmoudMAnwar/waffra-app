import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M486 #410 sender picker stays below SMS review/editor',(){
  final source=File('lib/main.dart').readAsStringSync();
  final inboxStart=source.indexOf('Future<void> _openAutoSmsInbox()async{');
  final cardStart=source.indexOf('Widget _autoSmsReviewCard(){',inboxStart);
  expect(inboxStart,greaterThanOrEqualTo(0));
  expect(cardStart,greaterThan(inboxStart));
  final inbox=source.substring(inboxStart,cardStart);

  // The sender picker is an owned route and must remain mounted while
  // nested SMS review, transfer, correction or account creation is shown.
  expect(inbox,contains('await showModalBottomSheet<void>('));
  expect(inbox,contains('await _reviewAutoSmsCandidates(targetId:id);'));
  expect(inbox,contains('openingReviewId=null;'));
  expect(inbox,contains('refresh(()=>selectedSender=null);'));
  expect(inbox,contains('if(selectedSender==null){Navigator.pop(ctx);}'));
  expect(inbox,contains('if(!_autoSmsPending.any((row)=>row[\'id\']==id))'));
  expect(inbox,contains('selectedIds.remove(id);'));
  expect(inbox,contains('The sender inbox route remains beneath the message review.'));

  // The old bug popped the picker before opening the next screen.
  expect(inbox, isNot(contains('Navigator.pop(ctx,id)')));
  expect(inbox, isNot(contains('WidgetsBinding.instance.addPostFrameCallback((_){')));
 });

 test('M486 #410 canceling nested editor cannot acknowledge bank SMS',(){
  final source=File('lib/main.dart').readAsStringSync();
  final detailStart=source.indexOf('Future<void> _reviewAutoSmsCandidates(');
  final end=source.indexOf('void _receiveSharedSms()',detailStart);
  expect(detailStart,greaterThanOrEqualTo(0));
  expect(end,greaterThan(detailStart));
  final detail=source.substring(detailStart,end);
  expect(detail,contains('await entrySheet(sms:true,initialSms:body);'));
  expect(detail,contains('if(smsHashes.contains(bankSmsHash(body)))'));
  expect(detail,contains('await WaffraAutoSms.acknowledge([id]);'));
  expect(detail,contains('_autoSmsReviewOpen=false;'));
 });
}

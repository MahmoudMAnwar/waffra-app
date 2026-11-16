import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1029 multiple independent same-sender SMS never concatenate across timestamps',(){
  final tuples=[
   ('ALRAJHI',1000,'smsc','شراء 10 SAR'),
   ('ALRAJHI',2000,'smsc','شراء 20 SAR'),
   ('ALRAJHI',1000,'smsc','تمت العملية'),
   ('SNB',1000,'smsc','دخل 45 SAR'),
  ];
  final grouped=<String,StringBuffer>{};
  for(final (sender,at,center,body) in tuples){
   final k='$sender|$at|$center';
   grouped.putIfAbsent(k,StringBuffer.new).write(body);
  }
  expect(grouped.length,3);
  expect(grouped['ALRAJHI|1000|smsc'].toString(),'شراء 10 SARتمت العملية');
  expect(grouped['ALRAJHI|2000|smsc'].toString(),'شراء 20 SAR');
 });
 test('M1029 receiver uses original segment identity and one worker job',(){
  final r=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(r,contains('val bySenderAndTimestamp = linkedMapOf<Triple<String, Long, String>, StringBuilder>()'));
  expect(r,contains('Triple(sender, sms.timestampMillis, sms.serviceCenterAddress ?: "")'));
  expect(r,contains('for ((messageKey, parts) in bySenderAndTimestamp)'));
  expect(r,contains('val sender = messageKey.first'));
  expect(r,contains('val receivedAt = messageKey.second'));
  expect(r,contains('WaffraAutoSmsStore.offer(context, sender, parts.toString(), receivedAt)'));
  expect(r,isNot(contains('val bySender = linkedMapOf<String, StringBuilder>()')));
  expect('WaffraAutoSmsWorker.enqueue(context)'.allMatches(r),hasLength(1));
 });
}

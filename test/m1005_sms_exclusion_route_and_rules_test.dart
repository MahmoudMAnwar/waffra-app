import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';
import 'package:waffra/main.dart' show snack, waffraM632ClassifySmsQueue;
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main(){
 const id='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
 const notice=WaffraReviewNotice(
  id:id,sender:'AlRajhiBank',preview:'Test SMS only',
  kind:'needsReview',receivedAtMs:1763280000000);

 testWidgets('M1005 excluded action failure stays selected and visible',(
  tester)async{
  var result=false;
  var calls=0;
  String? feedback;
  bool? lastError;
  final current=<WaffraReviewNotice>[notice];
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>current,
   onReviewAll:()async{},onReviewOne:(_)async{},onRescan:()async{},
   canRescan:()=>true,
   onFeedback:(ctx,message,isError){
    feedback=message;lastError=isError;
    snack(ctx,message,isError:isError);
   },
   onBulkExclude:(ids,senders)async{
    calls++;
    expect(ids,[id]);
    expect(senders,isEmpty);
    if(result)current.clear();
    return result;
   },
  )));
  await tester.tap(find.byKey(const Key('m589-open-bulk-sms-review')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('m592-select-all-visible')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('m592-confirm-bulk-exclude')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('الرسائل فقط'));
  await tester.pump(const Duration(milliseconds:200));
  expect(calls,1);
  expect(feedback,contains('لم يتم تأكيد الاستبعاد'));
  expect(lastError,isTrue);
  await tester.pump(const Duration(milliseconds:350));
  expect(find.byKey(const Key('m592-confirm-bulk-exclude')),findsOneWidget);
  expect(find.textContaining('لم يتم تأكيد الاستبعاد'),findsWidgets);
  expect(current.length,1);
  result=true;
  await tester.tap(find.byKey(const Key('m592-confirm-bulk-exclude')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('الرسائل فقط'));
  await tester.pump(const Duration(milliseconds:200));
  expect(calls,2);
  expect(feedback,contains('تم استبعاد 1 رسالة'));
  expect(lastError,isFalse);
  await tester.pump(const Duration(milliseconds:350));
  expect(current,isEmpty);
  expect(find.byKey(const Key('m592-confirm-bulk-exclude')),findsNothing);
  expect(find.textContaining('تم استبعاد 1 رسالة'),findsWidgets);
  expect(tester.takeException(),isNull);
 });

 test('M1005 classify all current queued SMS again when exclusion saved',(){
  const body='تم تحديث بيانات الملف الشخصي';
  const sender='AdminAlerts';
  const rule=WaffraSmsLocalRule(
   id:'custom_m1005_alert',name:'تنبيهات الحساب غير المالية',
   sender:sender,kind:'excluded',keywords:['تحديث بيانات'],
   income:false,category:'',matchAll:false);
  WaffraSmsLocalRules.validate(rule);
  final row=<String,Object?>{
   'id':id,'sender':sender,'body':body,'receivedAt':1763280000000,
  };
  Map<String,Object?> classify(List<Map<String,dynamic>> rules,{
   List<Map<String,Object?>> cache=const [],
   List<Map<String,dynamic>> previous=const [],
  })=>waffraM632ClassifySmsQueue({
   'results':<Map<String,Object?>>[row],
   'rules':rules,'categories':<String>[], 'hashes':<String>[],
   'history':<Map<String,Object?>>[],
   'previousRules':previous,
   'cached':cache,
  });
  final before=classify([]);
  expect(before['excluded'],isEmpty);
  final prior=(before['waiting'] as List).single as Map;
  final after=classify([rule.toJson()],cache:[
   Map<String,Object?>.from(prior),
  ]);
  expect(after['excluded'],contains(id));
  expect((after['waiting'] as List),isEmpty);
  // A valid exclusion for one sender cannot hide financial posted money
  // or a superficially similar notification from another sender.
  const paid='تم خصم 85 ريال. تم تحديث بيانات الملف الشخصي';
  final facts=WaffraBankSmsFactsParser.parse(paid);
  expect(WaffraSmsLocalRules.resolveSpecial(
   body:paid,sender:sender,bankKind:facts.kind,
   custom:[rule])?.resolvedKind,isNot('excluded'));
  expect(WaffraSmsLocalRules.matches(
   rule,body,sender:'AnotherSender'),isFalse);
 });
 test('M1005 stale native review ID is refreshed and never silently ignored',(){
  final src=File('lib/waffra_home_sms_confirmation.part.dart')
   .readAsStringSync();
  final start=src.indexOf('final direct=targetId==null?null:await WaffraAutoSms.pendingById(targetId);');
  final end=src.indexOf('Map<String,Object?>? selected;',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final guard=src.substring(start,end);
  expect(guard,contains('if(items.isEmpty){'));
  expect(guard,contains('await _refreshAutoSmsInbox();'));
  expect(guard,contains('snack(visibleContext,waffraIsEnglish?'));
  expect(guard,contains('الرسالة لم تعد موجودة'));
  expect(guard,isNot(contains('WaffraAutoSms.acknowledgeCommitted(')));
 });
 test('M1005 single Exclude always reports on the visible route and rechecks queue',(){
  // The review popup is dismissed before this code runs. The root
  // Snackbar is hidden behind the pushed Notifications route otherwise.
  final src=File('lib/waffra_home_sms_confirmation.part.dart')
   .readAsStringSync();
  final start=src.indexOf("}else if(decision=='exclude'&&mounted){");
  final end=src.indexOf("}else if(decision=='transfer'&&mounted)",start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final block=src.substring(start,end);
  expect(block,contains('final visibleContext=Navigator.of(context).canPop()?'));
  expect(block,contains('Navigator.of(context).context:context;'));
  expect(block,contains('await WaffraAutoSms.excludeMessages([id])'));
  expect(block,contains('snackSuccess(visibleContext,learned?'));
  expect(block,contains('snack(visibleContext,waffraIsEnglish?'));
  expect(block,contains('await _refreshAutoSmsInbox();'));
  expect(block,isNot(contains('unawaited(_refreshAutoSmsInbox());')));
 });


 test('M1005 BRKH bilingual OTP variants are security, never posted money',(){
  for(final text in <String>[
   '492617 is your code for Barakah رمز دخولك لبركة',
   'is your code for Barakah 492617 رمز دخولك لبركة',
  ]){
   expect(WaffraBankSmsFactsParser.isVerificationChallenge(text),isTrue);
   final facts=WaffraBankSmsFactsParser.parse(text);
   expect(facts.canAutoPostAsIncomeExpense,isFalse);
   expect(WaffraSmsLocalRules.resolveSpecial(body:text,
    sender:'BRKH',bankKind:facts.kind)?.resolvedKind,'excluded');
  }
  const paid='Purchase approved SAR 85.00; 492617 is your code for Barakah';
  final facts=WaffraBankSmsFactsParser.parse(paid);
  expect(WaffraSmsLocalRules.resolveSpecial(body:paid,
   sender:'BRKH',bankKind:facts.kind)?.resolvedKind,isNot('excluded'));
 });
}

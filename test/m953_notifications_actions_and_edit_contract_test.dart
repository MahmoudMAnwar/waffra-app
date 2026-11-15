import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 testWidgets('M953 notifications and sender filter sort newest arrival first '
  'without reclassifying or discarding SMS', (tester)async{
  final pending=<WaffraReviewNotice>[
   const WaffraReviewNotice(id:'old-a',sender:'BankA',preview:'Old A',
    receivedAtMs:1000),
   const WaffraReviewNotice(id:'new-b',sender:'BankB',preview:'New B',
    receivedAtMs:4000),
   const WaffraReviewNotice(id:'new-a',sender:'BankA',preview:'New A',
    receivedAtMs:3000),
   const WaffraReviewNotice(id:'old-b',sender:'BankB',preview:'Old B',
    receivedAtMs:2000),
  ];
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>pending,
   onReviewAll:()async{},onReviewOne:(id)async{},
   onRescan:()async{},canRescan:()=>true,
  )));
  await tester.pumpAndSettle();
  double y(String id)=>tester.getTopLeft(find.byKey(
   Key('m549-notification-message-$id'))).dy;
  expect(y('new-b'),lessThan(y('new-a')));
  expect(y('new-a'),lessThan(y('old-b')));
  expect(y('old-b'),lessThan(y('old-a')));
  await tester.tap(find.byKey(
   const Key('m580-notification-filter-sender:banka')));
  await tester.pumpAndSettle();
  expect(y('new-a'),lessThan(y('old-a')));
  expect(find.byKey(const Key('m549-notification-message-new-b')),findsNothing);
  expect(pending.map((n)=>n.id).toList(),
   ['old-a','new-b','new-a','old-b'],
   reason:'Sorting must never mutate underlying native queue');
  expect(tester.takeException(),isNull);
 });

 test('M953 native arrival timestamps are carried into notifications',(){
  final notices=File('lib/waffra_home_sms_management.part.dart')
   .readAsStringSync();
  expect(notices,contains("receivedAtMs:row['receivedAt'] is int"));
  final page=File('lib/waffra_approved_notifications.dart')
   .readAsStringSync();
  expect(page,contains('b.value.receivedAtMs.compareTo(a.value.receivedAtMs)'));
  expect(page,contains('a.key.compareTo(b.key)'));
 });

 test('M953 SMS review always has readable exclusion for non-sensitive '
  'unknown notices and full-width original three actions',(){
  final source=File('lib/waffra_home_sms_confirmation.part.dart')
   .readAsStringSync();
  expect(source,contains("key:const Key('m953-unknown-sms-exclude')"));
  expect(source,contains("key:const Key('m595-review-single-exclude')"));
  expect(source,contains("key:const Key('m587-sms-transfer-exclude')"));
  expect(source,contains("key:const Key('waffra-sms-understood-action')"));
  expect(source,contains("!(understood&&reviewType==(expectedIncome?'income':'expense'))"));
  expect(source,contains('Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:['));
 });

 test('M953 goals and dues use All dropdown totals only and visible '
  'copy says dues; backup/due editors keep scroll away from left-side RTL',(){
  final page=File('lib/waffra_home_goals_recurring_pages.part.dart')
   .readAsStringSync();
  expect(page,isNot(contains('WaffraOutlinedItemsCount(')));
  expect(page,contains("goalCounts[goalDisplay]"));
  expect(page,contains("dueCounts[recurringDisplay]"));
  expect(page,contains('الاستحقاقات المحذوفة'));
  final recurring=File('lib/waffra_home_recurring_workflows.part.dart')
   .readAsStringSync();
  expect(recurring,contains("'استحقاق جديد'"));
  expect(recurring,contains("'تعديل الاستحقاق'"));
  expect(recurring,contains('padding:const EdgeInsetsDirectional.only(end:18)'));
  final backup=File('lib/waffra_home_account_tools.part.dart')
   .readAsStringSync();
  expect(backup,contains('padding:const EdgeInsetsDirectional.only(end:18)'));
  final dashboard=File('lib/waffra_home_dashboard_analytics.part.dart')
   .readAsStringSync();
  expect(dashboard,contains("title:waffraIsEnglish?'Due dates':'الاستحقاقات'"));
  expect(dashboard,contains('_m953NumberedActivity(index+1'));
  expect(dashboard,contains('shown.indexed.map((row)=>_m953NumberedActivity'));
 });

 test('M953 encrypted edits keep unrelated original history bytes and '
  'recheck same ID using actual verified source before commit',(){
  final source=File('lib/waffra_home_entry_sheet.part.dart')
   .readAsStringSync();
  expect(source,contains('Future<bool> _m953SaveExistingVerifiedEntry('));
  expect(source,contains("route:WaffraFinanceRoute.transactionEdit"));
  expect(source,contains('final current=MoneyEntry.fromJson(raw);'));
  expect(source,contains("patched.add(Map<String,Object?>.from(raw))"));
  expect(source,contains('if(matches!=1)throw StateError'));
  expect(source,contains('await _refreshFromVerifiedFinance();'));
  expect(source,isNot(contains('تعذر حفظ المعاملة. بياناتك السابقة لم تتغير.')));
 });
}

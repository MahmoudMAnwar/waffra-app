import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';

void main(){
 testWidgets('M581 notification filters use exact per-message sender and no duplicate hero',(tester)async{
  final opened=<String>[];
  final notices=[const WaffraReviewNotice(
   id:'sms1',sender:'SyntheticBank',preview:'Purchase completed',
   kind:'expense',amount:120),
   const WaffraReviewNotice(
   id:'sms2',sender:'OtherBank',preview:'Verification message',
   kind:'otpReview'),
   const WaffraReviewNotice(
   id:'sms3',sender:'SyntheticBank',preview:'Incoming transfer',
   kind:'income',amount:250)];
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>notices,
   onReviewAll:()async{throw StateError('obsolete review hero');},
   onReviewOne:(id)async{opened.add(id);},
   onRescan:()async{},canRescan:()=>true)));
  expect(find.byKey(const Key('m549-notification-review-hero')),findsNothing);
  expect(find.text('Purchase completed'),findsOneWidget);
  expect(find.text('رسالة تحقق — تحتاج مراجعة'),findsOneWidget);
  expect(find.byKey(const Key('m580-sender-filters')),findsOneWidget);
  await tester.tap(find.byKey(
   const Key('m580-notification-filter-sender:otherbank')));
  await tester.pump();
  expect(find.text('Verification message'),findsOneWidget);
  expect(find.text('Purchase completed'),findsNothing);
  await tester.tap(find.byKey(const Key('m549-notification-message-sms2')));
  await tester.pump();
  await tester.pump();
  expect(opened,['sms2']);
 });

 testWidgets('M589 compact bulk action opens the verified select/exclude route',(tester)async{
  var bulkOpens=0;
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>[const WaffraReviewNotice(
    id:'sms1',sender:'Bank',preview:'review')],
   onReviewAll:()async{bulkOpens++;},
   onReviewOne:(id)async{},
   onRescan:()async{},canRescan:()=>true)));
  expect(find.byKey(const Key('m549-notification-review-hero')),findsNothing);
  await tester.tap(find.byKey(const Key('m589-open-bulk-sms-review')));
  await tester.pump();
  await tester.pump();
  expect(bulkOpens,1);
 });

 testWidgets('M581 empty sender list shows one helpful state',(tester)async{
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>[],
   onReviewAll:()async{},onReviewOne:(id)async{},
   onRescan:()async{},canRescan:()=>false)));
  expect(find.text('لا توجد رسائل تحتاج للمراجعة'),findsOneWidget);
  expect(find.byKey(const Key('m549-notification-review-hero')),findsNothing);
  expect(find.byKey(const Key('m580-notification-filter-all')),findsOneWidget);
 });

 test('M549 approved Home bell saturated at +999; FAB is unchanged',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains("Key('m549-header-notification-bell')"));
  expect(main,contains("_autoSmsPending.length>999?'+999'"));
  expect(main,contains('WaffraDirectionalFabLocation(english:waffraIsEnglish)'));
  expect(main,contains('WaffraStationaryFabAnimator()'));
  final dashboard=main.substring(main.indexOf(' Widget dashboard(){'),
   main.indexOf(' Widget _currentTabContents(){'));
  expect(dashboard,isNot(contains('          _autoSmsReviewCard(),')));
  expect(dashboard,contains('monthlySummaryCard(),'));
  // The approved three compact finance actions use existing verified flows.
  expect(dashboard,contains("Key('m549-three-home-finance-actions')"));
  expect(dashboard,contains('entrySheet(scannedIncome:true)'));
  expect(dashboard,contains('entrySheet(scannedIncome:false)'));
  expect(dashboard,contains('openVerifiedTransfer()'));
  expect(dashboard,isNot(contains("homeSummaryCard(waffraIsEnglish?'Income'")));
  final summary=main.substring(main.indexOf(' Widget monthlySummaryCard(){'),
   main.indexOf(' Widget smartMoneyInsightsCard(){'));
  expect(summary,contains("Key('m549-home-account-filter')"));
  expect(summary,contains('_m467PickHomeAccount()'));
 });
}

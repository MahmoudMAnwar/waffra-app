import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_notifications.dart';

void main(){
 testWidgets('M549 notifications show only real pending messages and review CTA',(tester)async{
  var reviews=0;
  final notices=[const WaffraReviewNotice(
   id:'sms1',sender:'AlRajhiBank',preview:'عملية شراء',
   kind:'expense',amount:120)];
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>notices,
   onReviewAll:()async{reviews++;},
   onReviewOne:(id)async{reviews++;},
   onRescan:()async{},canRescan:()=>false)));
  expect(find.byKey(const Key('m549-notification-review-hero')),findsOneWidget);
  expect(find.text('عملية شراء'),findsOneWidget);
  expect(find.text('1 رسالة بنكية تنتظر التصنيف والتأكيد'),findsOneWidget);
  await tester.tap(find.byKey(const Key('m549-open-all-sms-review')));
  await tester.pump();
  expect(reviews,1);
 });

 testWidgets('M549 empty App tab never invents updates',(tester)async{
  await tester.pumpWidget(MaterialApp(home:WaffraApprovedNotificationsPage(
   english:false,readPending:()=>[],
   onReviewAll:()async{},onReviewOne:(id)async{},
   onRescan:()async{},canRescan:()=>false)));
  expect(find.byKey(const Key('m549-open-all-sms-review')),findsOneWidget);
  await tester.tap(find.byKey(const Key('m549-notification-filter-updates')));
  await tester.pump();
  expect(find.text('لا توجد إشعارات في هذا القسم'),findsOneWidget);
  expect(find.byKey(const Key('m549-notification-review-hero')),findsNothing);
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

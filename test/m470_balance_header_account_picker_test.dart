import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraBalanceHeader;

void main(){
 testWidgets('M549 approved Home balance never embeds an account dropdown',(tester)async{
  var legacyClicks=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(delegate:WaffraBalanceHeader(
     balance:2500,english:false,heading:'إجمالي الرصيد',compact:true,
     selectedAccountLabel:'كل الحسابات',
     onAccountTap:()=>legacyClicks++,
     refreshVerifiedWidgetBalance:()async{},
    )),
   ]),
  )));
  expect(find.byKey(const Key('waffra-approved-emerald-balance-card')),findsOneWidget);
  expect(find.byKey(const Key('m470-balance-account-picker')),findsNothing);
  expect(legacyClicks,0);
 });

 testWidgets('M549 other balance cards also have no accidental account picker',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(delegate:WaffraBalanceHeader(
     balance:1,english:true,refreshVerifiedWidgetBalance:()async{})),
   ]),
  )));
  expect(find.byKey(const Key('m470-balance-account-picker')),findsNothing);
 });

 test('M549 the real account selector is in month summary, not balance header',(){
  final src=File('lib/main.dart').readAsStringSync();
  final start=src.indexOf('Widget monthlySummaryCard(){');
  final end=src.indexOf('Widget smartMoneyInsightsCard(){',start);
  final summary=src.substring(start,end);
  expect(summary,contains("Key('m549-home-account-filter')"));
  expect(summary,contains('_m467PickHomeAccount()'));
  final balance=src.substring(src.indexOf('class WaffraBalanceHeader'),
   src.indexOf('class _HomeScreenState'));
  expect(balance,isNot(contains("Key('m470-balance-account-picker')")));
 });
}

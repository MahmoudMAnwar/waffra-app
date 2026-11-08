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
 testWidgets('M470 generic balance card has no account-switching action',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(delegate:WaffraBalanceHeader(
     balance:1,english:true,refreshVerifiedWidgetBalance:()async{})),
   ]),
  )));
  expect(find.byKey(const Key('m470-balance-account-picker')),findsNothing);
 });
}

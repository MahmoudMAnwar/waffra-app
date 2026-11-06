import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show WaffraBalanceHeader;

void main(){
 testWidgets('M470 account selector is clickable inside verified Home balance card',(tester)async{
  var clicks=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(
   body:CustomScrollView(slivers:[
    SliverPersistentHeader(delegate:WaffraBalanceHeader(
     balance:2500,english:false,
     selectedAccountLabel:'كل الحسابات',
     onAccountTap:()=>clicks++,
     refreshVerifiedWidgetBalance:()async{},
    )),
   ]),
  )));
  expect(find.byKey(const Key('waffra-approved-emerald-balance-card')),findsOneWidget);
  final picker=find.byKey(const Key('m470-balance-account-picker'));
  expect(picker,findsOneWidget);
  await tester.tap(picker);
  await tester.pump();
  expect(clicks,1);
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

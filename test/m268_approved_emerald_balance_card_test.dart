import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_balance_art.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('approved balance artwork stays embedded and never uses external images',(){
  final main=File('lib/main.dart').readAsStringSync();
  final artwork=File('lib/waffra_balance_art.dart').readAsStringSync();
  expect(main,contains('waffra-approved-emerald-balance-card'));
  expect(main,contains('WaffraBalanceIllustration()'));
  expect(main,contains('WaffraBalanceWavePainter('));
  expect(main,contains('monthlyChangePercent:monthChange'));
  expect(main,contains('hasPreviousMonthEntries&&previousClosingBalance>0'));
  expect(artwork,contains('class WaffraBalanceIllustration'));
  expect(artwork,contains('linearGradient id="gold"'));
  expect(artwork,contains('linearGradient id="leaf"'));
  expect(artwork, isNot(contains('http.get(')));
 });

 for(final brightness in [Brightness.light,Brightness.dark]){
  testWidgets('emerald total balance card scales, keeps privacy and verified refresh: $brightness',
   (tester)async{
   tester.view.physicalSize=const Size(320,640);
   tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   SharedPreferences.setMockInitialValues({});
   hideWaffraAmounts.value=false;
   addTearDown(()=>hideWaffraAmounts.value=false);
   var refreshed=0;
   await tester.pumpWidget(MaterialApp(
    theme:ThemeData(brightness:brightness,useMaterial3:true,fontFamily:'Tajawal'),
    home:Scaffold(body:CustomScrollView(slivers:[
     SliverPersistentHeader(pinned:false,
      delegate:WaffraBalanceHeader(
       balance:12480,english:false,monthlyChangePercent:12.5,
       refreshVerifiedWidgetBalance:()async{refreshed++;})),
     const SliverToBoxAdapter(child:SizedBox(height:700)),
    ]))));
   await tester.pumpAndSettle();
   expect(find.byKey(const Key('waffra-approved-emerald-balance-card')),findsOneWidget);
   expect(find.byType(WaffraBalanceIllustration),findsOneWidget);
   expect(find.text('إجمالي رصيدك'),findsWidgets);
   expect(find.byIcon(Icons.visibility_outlined),findsOneWidget);
   expect(find.byKey(const Key('waffra-balance-month-comparison')),findsOneWidget);
   expect(find.text('+13%'),findsOneWidget);
   expect(tester.takeException(),isNull);

   await tester.tap(find.byKey(const Key('waffra-balance-privacy-eye')));
   await tester.pumpAndSettle();
   expect(find.text('***'),findsWidgets);
   expect(find.byIcon(Icons.visibility_off_outlined),findsOneWidget);
   expect(refreshed,1);
   expect(tester.takeException(),isNull);
  });
 }

 testWidgets('no previous month history shows no invented comparison',(tester)async{
  hideWaffraAmounts.value=false;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:CustomScrollView(
   slivers:[
    SliverPersistentHeader(delegate:WaffraBalanceHeader(
     balance:300,english:true,refreshVerifiedWidgetBalance:()async{})),
    const SliverToBoxAdapter(child:SizedBox(height:700)),
   ]))));
  expect(find.text('Total balance'),findsWidgets);
  expect(find.byKey(const Key('waffra-balance-month-comparison')),findsNothing);
  expect(tester.takeException(),isNull);
 });
}

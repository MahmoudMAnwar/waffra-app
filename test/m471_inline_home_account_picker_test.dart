import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_home_accounts_sheet.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M471 account selector is inside the home balance card with no extra row', () {
  final main=File('lib/main.dart').readAsStringSync();
  final from=main.indexOf('SliverToBoxAdapter(child:Padding(',main.indexOf('final shown=visible.take('));
  final to=main.indexOf('SliverPadding(padding:const EdgeInsets.fromLTRB(14,10,14,96)',from);
  expect(from,greaterThanOrEqualTo(0));
  expect(to,greaterThan(from));
  final home=main.substring(from,to);
  expect(home,contains('accountPickerLabel:_m467AccountLabel'));
  expect(home,contains('onPickAccount:()=>unawaited(_m467PickHomeAccount())'));
  expect(home,isNot(contains('child:WaffraHomeAccountChip(')),
   reason:'The old standalone account-filter row must not use home height.');
  expect(home,isNot(contains('بدون حساب — لا يوجد رصيد مرتبط')));
  expect(main,contains('if(onPickAccount!=null)'));
  expect(main,contains('WaffraHomeAccountChip('));
  expect(main,contains('_m467ShownBalance()'));
  expect(main,contains('_m467ScopedEntries().toList()'));
 });

 for(final brightness in [Brightness.light,Brightness.dark]) {
  testWidgets('M471 compact selector opens from card and preserves amount and eye ($brightness)',(tester)async {
   tester.view.physicalSize=const Size(320,640);
   tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   SharedPreferences.setMockInitialValues({});
   hideWaffraAmounts.value=false;
   addTearDown(()=>hideWaffraAmounts.value=false);
   var taps=0;
   await tester.pumpWidget(MaterialApp(
    theme:ThemeData(brightness:brightness,useMaterial3:true,fontFamily:'Tajawal'),
    locale:const Locale('ar'),
    home:Scaffold(body:CustomScrollView(slivers:[
     SliverPersistentHeader(pinned:false,delegate:WaffraBalanceHeader(
      balance:1234.50,english:false,
      accountPickerLabel:'كل الحسابات',
      onPickAccount:(){taps++;},
      refreshVerifiedWidgetBalance:()async{})),
     const SliverToBoxAdapter(child:SizedBox(height:700)),
    ]))));
   await tester.pumpAndSettle();
   expect(find.byKey(const Key('waffra-approved-emerald-balance-card')),findsOneWidget);
   expect(find.byKey(const Key('m467-home-account-picker')),findsOneWidget);
   expect(find.text('كل الحسابات'),findsOneWidget);
   expect(find.byKey(const Key('waffra-balance-privacy-eye')),findsOneWidget);
   expect(find.text('الرصيد المتاح للصرف'),findsNothing);
   expect(tester.takeException(),isNull);
   await tester.tap(find.byKey(const Key('m467-home-account-picker')));
   await tester.pump();
   expect(taps,1);
   expect(tester.takeException(),isNull);
  });
 }

 testWidgets('M471 long sender/account names ellipsize without overflow',(tester)async{
  tester.view.physicalSize=const Size(320,640);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
   child:SizedBox(width:190,child:WaffraHomeAccountChip(
    label:'الإنماء المحفظة الاستثمارية وحساب ادخار طويل جدًا •••• 7856',
    english:false,onTap:_noop))))));
  await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
  expect(find.byKey(const Key('m467-home-account-picker')),findsOneWidget);
 });
}

void _noop() {}

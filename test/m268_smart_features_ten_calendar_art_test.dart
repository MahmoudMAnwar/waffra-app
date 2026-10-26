import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smart_features.dart';
import 'package:waffra/waffra_today_picker.dart';

WaffraSmartEntry row(String id,String title,String category,double amount,
 int year,int month,int day,{bool income=false})=>
 WaffraSmartEntry(id:id,title:title,category:category,amount:amount,
  income:income,date:DateTime(year,month,day));

void main(){
 group('M268: deterministic read-only financial calculations',(){
  test('payday never lands in past and clamps to month length',(){
   expect(waffraNextPayday(DateTime(2026,10,27),31),DateTime(2026,10,31));
   expect(waffraNextPayday(DateTime(2026,10,31),31),DateTime(2026,11,30));
   expect(waffraNextPayday(DateTime(2027,2,1),31),DateTime(2027,2,28));
  });
  test('balance and category totals never count incoming money as spending',(){
   final rows=[
    row('1','Salary','راتب',3000,2026,10,1,income:true),
    row('2','Coffee','مطاعم',45.25,2026,10,12),
    row('3','Taxi','مواصلات',22.50,2026,9,12),
   ];
   expect(waffraSmartBalance(rows),2932.25);
   expect(waffraCategoryOutflows(rows,start:DateTime(2026,10)),{'مطاعم':45.25});
   expect(waffraCategoryOutflows(rows,end:DateTime(2026,10)),{'مواصلات':22.5});
  });
  test('subscriptions need distinct months and consistent amounts',(){
   final rows=[
    row('1','Streaming','اشتراكات',20,2026,8,5),
    row('2','Streaming','اشتراكات',22,2026,9,5),
    row('3','Streaming','اشتراكات',19,2026,10,5),
    row('4','Groceries','تسوق',200,2026,10,4),
    row('5','Groceries','تسوق',420,2026,9,4),
    row('6','Streaming','اشتراكات',1,2026,10,5,income:true),
   ];
   final matches=waffraSmartSubscriptions(rows);
   expect(matches.length,1);
   expect(matches.single.name,'Streaming');
   expect(matches.single.months,3);
  });
  test('possible duplicate is a review flag, not a financial mutation',(){
   final rows=[
    row('1','Store','تسوق',84.72,2026,10,10),
    row('2','Store','تسوق',84.72,2026,10,12),
    row('3','Store','تسوق',85,2026,10,12),
    row('4','Store','تسوق',84.72,2026,10,24),
   ];
   final flagged=waffraPotentialDuplicates(rows);
   expect(flagged.map((e)=>e.id).toList(),['2']);
   expect(rows.length,4);
  });
  test('recurring cash forecast uses inclusive current day and exclusive payday',(){
   final list=[
    const WaffraSmartRecurring('Rent',1000,30,false),
    const WaffraSmartRecurring('Internet',100,5,false),
    const WaffraSmartRecurring('Salary',3000,5,true),
   ];
   expect(waffraProjectedRecurringOutflows(DateTime(2026,10,27),
     DateTime(2026,11,10),list),1100);
   expect(waffraProjectedRecurringOutflows(DateTime(2026,10,27),
     DateTime(2026,10,29),list),0);
  });
  test('today comparison ignores hour and minute',(){
   expect(waffraCalendarIsToday(DateTime(2026,10,27,1),
     now:DateTime(2026,10,27,23)),isTrue);
   expect(waffraCalendarIsToday(DateTime(2026,10,26),
     now:DateTime(2026,10,27)),isFalse);
  });
 });

 group('M268: translated illustrated feature hub',(){
  final sample=[
    row('1','Salary','راتب',1250,2026,10,1,income:true),
    row('2','Groceries','تسوق',100,2026,10,2),
  ];
  testWidgets('hub exposes ten distinct read-only feature cards',(tester)async{
   await tester.pumpWidget(MaterialApp(home:WaffraSmartFeaturesPage(
    entries:sample,goals:const [],recurring:const [],english:false)));
   expect(find.byKey(const Key('waffra-m268-feature-runway')),findsOneWidget);
   expect(find.byKey(const Key('waffra-m268-feature-subscription')),findsOneWidget);
   expect(find.text('١٠ أدوات مالية ذكية'),findsOneWidget);
  });
  testWidgets('simulation is interactive but does not change input data',(tester)async{
   await tester.pumpWidget(MaterialApp(home:WaffraSmartFeaturesPage(
    entries:sample,goals:const [],recurring:const [],english:true)));
   await tester.tap(find.byKey(const Key('waffra-m268-feature-simulation')));
   await tester.pumpAndSettle();
   expect(find.text('Hypothetical purchase (SAR) — 3500'),findsOneWidget);
   expect(sample.length,2);
   expect(waffraSmartBalance(sample),1150);
   expect(find.textContaining('Simulation only'),findsOneWidget);
  });
  testWidgets('illustrations work with dark theme and local direction',(tester)async{
   await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),
    home:const Directionality(textDirection:TextDirection.rtl,
     child:Scaffold(body:WaffraIllustration(topic:'restaurant')))));
   expect(find.text('🍽️'),findsOneWidget);
  });
 });
}

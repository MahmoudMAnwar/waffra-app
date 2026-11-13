import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_page_designs.dart';

/// M693 / #635: production widget-composition layout matrix, NOT a screenshot
/// from the actual Android Home State. The physical device gate stays open.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 const longAr='تم حفظ العملية بنجاح مع توضيح جميع التفاصيل في أكثر من سطر بدون أي تحريك لزر الإضافة الثابت';
 const longEn='The operation was saved with complete details across multiple lines, without moving the persistent Add button';
 Widget scene(String page,{required bool english,required bool dark,
   required String notice}){
  final link=LayerLink();
  final title=switch(page){
   'goals'=>english?'Savings goals':'أهداف الادخار',
   'dues'=>english?'Due dates':'الاستحقاقات',
   _=>english?'Review messages':'مراجعة الرسائل',
  };
  final cards=<Widget>[
   WaffraApprovedPageHero(title:title,
    subtitle:english?'Your financial activity':'عملياتك المالية',
    icon:page=='goals'?Icons.flag_outlined:
     page=='dues'?Icons.calendar_month_outlined:Icons.sms_outlined),
   const SizedBox(height:12),
   if(page=='goals')...[
    const WaffraApprovedMetrics(metrics:[
     WaffraApprovedMetric('المدخرات','50,000.00 SAR',Icons.toll_outlined),
     WaffraApprovedMetric('الإنجاز','100%',Icons.donut_large),
     WaffraApprovedMetric('الأهداف','2',Icons.track_changes),
    ]),
    const SizedBox(height:12),
    WaffraApprovedGoalProgressBars(title:english?'Goal progress':'تقدم الأهداف',
     labels:const ['هدف ادخار'],progress:const [1]),
   ],
   if(page=='dues')...[
    WaffraApprovedSectionTitle(english?'Upcoming dues':'الاستحقاقات القادمة',
     icon:Icons.event_available_outlined),
    const WaffraApprovedStatusPill(
     label:'مستحق',icon:Icons.schedule_outlined,attention:true),
    const SizedBox(height:12),
    const Text('1,250.00 SAR',textAlign:TextAlign.center),
   ],
   if(page=='sms')...[
    WaffraApprovedSectionTitle(english?'Original SMS':'نص الرسالة الأصلي',
      icon:Icons.sms_outlined),
    const Text('Purchase completed: SAR 125.00'),
    const SizedBox(height:12),
    Wrap(spacing:6,runSpacing:6,children:[
     for(final label in <String>['دخل','مصروف','تحويل'])
      OutlinedButton(onPressed:(){},child:Text(label)),
    ]),
   ],
  ];
  return MaterialApp(
   theme:ThemeData(useMaterial3:true,
    brightness:dark?Brightness.dark:Brightness.light),
   builder:(context,child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(
     textScaler:const TextScaler.linear(1.3)),child:child!),
   home:Directionality(
    textDirection:english?TextDirection.ltr:TextDirection.rtl,
    child:Scaffold(body:Stack(children:[
     Positioned.fill(child:SingleChildScrollView(
      child:Padding(padding:const EdgeInsets.all(12),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
        children:cards)))),
     Positioned(left:english?null:16,right:english?16:null,bottom:82,
      child:CompositedTransformTarget(link:link,
       child:const SizedBox(key:Key('m693-fixed-plus'),
        width:58,height:58))),
     WaffraApprovedFixedFabNoticePosition(link:link,english:english,
      child:Material(child:Padding(padding:const EdgeInsets.all(8),
       child:Text(notice,key:const Key('m693-notice'),
        style:const TextStyle(fontSize:12))))),
    ]))));
 }
 testWidgets('M693 3 approved widget sets x 12 Android-width/theme/direction cases',
  (tester)async{
  addTearDown((){
   tester.view.resetPhysicalSize();
   tester.view.resetDevicePixelRatio();
  });
  for(final page in <String>['goals','dues','sms']){
   for(final width in <double>[320,360,390]){
    for(final dark in <bool>[false,true]){
     for(final english in <bool>[false,true]){
      tester.view.physicalSize=Size(width,740);
      tester.view.devicePixelRatio=1;
      await tester.pumpWidget(scene(page,english:english,dark:dark,
       notice:english?'Saved':'تم الحفظ'));
      await tester.pumpAndSettle();
      final plus=tester.getRect(find.byKey(const Key('m693-fixed-plus')));
      final short=tester.getRect(find.byKey(const Key('m693-notice')));
      expect(find.byKey(const Key('m674-premium-page-hero')),findsOneWidget);
      expect(tester.takeException(),isNull,
       reason:'short page=$page width=$width dark=$dark en=$english');
      await tester.pumpWidget(scene(page,english:english,dark:dark,
       notice:english?longEn:longAr));
      await tester.pumpAndSettle();
      final fixed=tester.getRect(find.byKey(const Key('m693-fixed-plus')));
      final long=tester.getRect(find.byKey(const Key('m693-notice')));
      expect(fixed,plus,reason:'FAB must not move on multilines');
      expect(long.height,greaterThan(short.height));
      if(english){
       expect(long.right,lessThanOrEqualTo(plus.left-7));
      }else{
       expect(long.left,greaterThanOrEqualTo(plus.right+7));
      }
      expect(tester.takeException(),isNull,
       reason:'wrapped page=$page width=$width dark=$dark en=$english');
     }
    }
   }
  }
 });
 test('M693 production Goals/Dues/SMS Review still route to real widgets',(){
  final main=File('lib/main.dart').readAsStringSync();
  expect(main,contains('Widget goalsPage(){'));
  expect(main,contains('Widget recurringPage(){'));
  expect(main,contains('Future<void> _reviewAutoSmsCandidates({'));
  expect(main,contains('WaffraApprovedPageHero('));
  expect(main,contains("Key('m595-review-single-exclude')"));
 });
}

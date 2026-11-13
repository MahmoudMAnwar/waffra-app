import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_approved_page_designs.dart';

/// Emulator/widget matrix. Physical Android pixels and owner backup
/// verification are separate gates, never inferred from green widget tests.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 final longArabic='تم تسجيل العملية بنجاح وإظهار تفاصيل إضافية من سطرين أو ثلاثة دون تحريك زر الإضافة في أي صفحة';
 final longEnglish='The completed operation has a longer confirmation which wraps over multiple lines without moving the fixed add action';
 Widget scene({required double width,required bool english,required bool dark,
  required String notice}){
  final link=LayerLink();
  final metrics=WaffraApprovedMetrics(metrics:[
   WaffraApprovedMetric(english?'Savings':'المدخرات',
    '50,000.00 SAR',Icons.toll_outlined),
   WaffraApprovedMetric(english?'Active':'نشطة',
    '2',Icons.track_changes_outlined),
   WaffraApprovedMetric(english?'Completed':'الإنجاز',
    '100%',Icons.donut_large),
  ]);
  return MaterialApp(
   theme:ThemeData(brightness:dark?Brightness.dark:Brightness.light,
    useMaterial3:true),
   builder:(context,child)=>MediaQuery(
    data:MediaQuery.of(context).copyWith(
     textScaler:const TextScaler.linear(1.3)),child:child!),
   home:Directionality(textDirection:english?TextDirection.ltr:TextDirection.rtl,
    child:Scaffold(body:Stack(children:[
     Positioned.fill(child:SingleChildScrollView(
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraApprovedPageHero(title:english?'Savings goals':'أهداف الادخار',
        subtitle:english?'Plan and save':'خطط وادخر',icon:Icons.flag_outlined),
       const SizedBox(height:12),
       metrics,
       const SizedBox(height:12),
       WaffraApprovedGoalProgressBars(
        title:english?'Your goals':'تقدم الأهداف',
        labels:[english?'Goal A':'هدف أ'],progress:const [.75]),
      ]))),
     Positioned(left:english?null:16,right:english?16:null,bottom:82,
      child:CompositedTransformTarget(link:link,
       child:const SizedBox(key:Key('m688-stationary-plus'),
        width:58,height:58))),
     WaffraApprovedFixedFabNoticePosition(link:link,english:english,
      child:Material(child:Padding(padding:const EdgeInsets.all(8),
       child:Text(notice,key:const Key('m688-multiline-notice'),
        style:const TextStyle(fontSize:12))))),
    ])))),
  );
 }
 testWidgets('M688 320/360/390 light/dark RTL/LTR remain readable and keep + fixed',
  (tester)async{
  addTearDown((){
   tester.view.resetPhysicalSize();
   tester.view.resetDevicePixelRatio();
  });
  for(final width in <double>[320,360,390]){
   for(final dark in <bool>[false,true]){
    for(final english in <bool>[false,true]){
     tester.view.physicalSize=Size(width,740);
     tester.view.devicePixelRatio=1;
     final short=scene(width:width,english:english,dark:dark,
      notice:english?'Saved':'تم الحفظ');
     await tester.pumpWidget(short);
     await tester.pumpAndSettle();
     final plus=tester.getRect(find.byKey(const Key('m688-stationary-plus')));
     final shortNotice=tester.getRect(find.byKey(const Key('m688-multiline-notice')));
     expect(find.text('50,000.00 SAR'),findsOneWidget);
     expect(find.text('100%'),findsOneWidget);
     expect(find.byKey(const Key('m674-premium-page-hero')),findsOneWidget);
     expect(tester.takeException(),isNull,
      reason:'short layout width=$width dark=$dark english=$english');
     await tester.pumpWidget(scene(width:width,english:english,dark:dark,
      notice:english?longEnglish:longArabic));
     await tester.pumpAndSettle();
     final moved=tester.getRect(find.byKey(const Key('m688-stationary-plus')));
     final longNotice=tester.getRect(find.byKey(const Key('m688-multiline-notice')));
     expect(moved,plus,reason:'FAB must never shift when notice wraps');
     expect(longNotice.height,greaterThan(shortNotice.height));
     if(english){
      expect(longNotice.right,lessThanOrEqualTo(plus.left-7));
     }else{
      expect(longNotice.left,greaterThanOrEqualTo(plus.right+7));
     }
     expect(tester.takeException(),isNull,
      reason:'wrapped layout width=$width dark=$dark english=$english');
    }
   }
  }
 });
}

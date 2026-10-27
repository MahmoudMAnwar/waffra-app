import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_pdf_reader.dart';
import 'package:waffra/main.dart';

Future<Uint8List> _samplePage()async{
 final recorder=ui.PictureRecorder();
 final canvas=Canvas(recorder);
 canvas.drawColor(Colors.white,BlendMode.src);
 canvas.drawRect(const Rect.fromLTWH(0,0,100,200),Paint()..color=Colors.green);
 final image=await recorder.endRecording().toImage(100,200);
 final png=await image.toByteData(format:ui.ImageByteFormat.png);
 image.dispose();
 return png!.buffer.asUint8List();
}

void main(){
 testWidgets('The redesigned footer preserves six tabs and active position',(tester)async{
  await tester.binding.setSurfaceSize(const Size(393,852));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  var selected=0;
  await tester.pumpWidget(MaterialApp(home:StatefulBuilder(builder:(ctx,update)=>
   Scaffold(body:const SizedBox.expand(),
    bottomNavigationBar:WaffraFooterNavigation(
     selectedIndex:selected,english:false,
     onSelected:(next)=>update(()=>selected=next))))));
  expect(find.byKey(const Key('waffra-modern-footer')),findsOneWidget);
  for(var index=0;index<6;index++){
   expect(find.byKey(Key('waffra-nav-$index')),findsOneWidget);
  }
  expect(tester.takeException(),isNull);
  await tester.tap(find.byKey(const Key('waffra-nav-1')));
  await tester.pumpAndSettle();
  expect(selected,1);
  expect(tester.takeException(),isNull);
  await tester.tap(find.byKey(const Key('waffra-nav-2')));
  await tester.pumpAndSettle();
  expect(selected,2);
  expect(find.text('الأدوات'),findsOneWidget);
  expect(find.text('الأهداف'),findsOneWidget);
  expect(find.text('التحليل الذكي'),findsNothing);
 });

 testWidgets('PDF page opens full-screen, navigates and returns to overview',(tester)async{
  await tester.binding.setSurfaceSize(const Size(390,850));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  final bytes=await tester.runAsync<Uint8List>(_samplePage);
  expect(bytes,isNotNull);
  final pages=List<WaffraPdfPage>.generate(3,(_)=>WaffraPdfPage(bytes!,.5));
  await tester.pumpWidget(MaterialApp(home:WaffraPdfReader(
   bytes:Uint8List(0),fileName:'report.pdf',english:false,
   previewPages:Future.value(pages))));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-pdf-page-0')),findsOneWidget);
  await tester.tap(find.byKey(const Key('waffra-pdf-page-0')));
  await tester.pumpAndSettle();
  expect(find.text('1 / 3'),findsOneWidget);
  await tester.tap(find.byTooltip('الصفحة التالية'));
  await tester.pumpAndSettle();
  expect(find.text('2 / 3'),findsOneWidget);
  await tester.tap(find.byTooltip('العودة للتقرير'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('waffra-pdf-page-0')),findsOneWidget);
  expect(tester.takeException(),isNull);
 });

 testWidgets('PDF zoom works on first tap and resets between report pages',
    (tester)async{
  await tester.binding.setSurfaceSize(const Size(393,850));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  final bytes=await tester.runAsync<Uint8List>(_samplePage);
  final pages=List<WaffraPdfPage>.generate(2,(_)=>WaffraPdfPage(bytes!,0.5));
  await tester.pumpWidget(MaterialApp(home:WaffraPdfReader(
   bytes:Uint8List(0),fileName:'report.pdf',english:false,
   previewPages:Future.value(pages))));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('waffra-pdf-page-0')));
  await tester.pumpAndSettle();
  InteractiveViewer viewer()=>tester.widget<InteractiveViewer>(
   find.byKey(const Key('waffra-pdf-full-page-0')));
  expect(viewer().transformationController!.value.getMaxScaleOnAxis(),1);
  await tester.tap(find.byTooltip('تكبير'));
  await tester.pumpAndSettle();
  expect(viewer().transformationController!.value.getMaxScaleOnAxis(),
   greaterThan(1));
  expect(tester.widget<PageView>(find.byType(PageView)).physics,
   isA<NeverScrollableScrollPhysics>());
  await tester.tap(find.byTooltip('إعادة الحجم الطبيعي'));
  await tester.pumpAndSettle();
  expect(viewer().transformationController!.value.getMaxScaleOnAxis(),1);
  final imageCenter=tester.getCenter(
   find.byKey(const Key('waffra-pdf-full-page-0')));
  await tester.tapAt(imageCenter);
  await tester.pump(const Duration(milliseconds:70));
  await tester.tapAt(imageCenter);
  await tester.pumpAndSettle();
  expect(viewer().transformationController!.value.getMaxScaleOnAxis(),
   greaterThan(1));
  await tester.tap(find.byTooltip('الصفحة التالية'));
  await tester.pumpAndSettle();
  expect(find.text('2 / 2'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });

 test('Smart Analysis screen and PDF use the same 90-day chart model',(){
  final now=DateTime(2026,10,25,12);
  MoneyEntry row(String key,int y,int m,int d,double amount,bool income,
    String category)=>MoneyEntry(
     id:key,title:key,category:category,amount:amount,income:income,
     date:DateTime(y,m,d,10));
  final rows=[
   row('p1',2026,8,3,10,true,'راتب / راتب أساسي'),
   row('p2',2026,9,3,18,false,'صحة / أطباء'),
   row('p3',2026,10,1,30,false,'بقالة وتموين / سوبرماركت'),
   row('p4',2026,10,24,42,false,'بقالة وتموين / سوبرماركت'),
   row('income',2026,10,24,100,true,'حوالات واردة / حوالة محلية'),
  ];
  final model=waffraSmartChartData(rows,now);
  expect(model.periods,[(10.0,0.0),(0.0,18.0),(100.0,72.0)]);
  expect(model.weeklySpend,hasLength(4));
  expect(model.weeklySpend.first,30);
  expect(model.weeklySpend.last,42);
  expect(model.topCategories.first.key,'بقالة وتموين / سوبرماركت');
  expect(model.topCategories.first.value,72);
  final code=File('lib/main.dart').readAsStringSync();
  expect(code,contains('weeklySpendSvg(smartData!.weeklySpend.map(pdfAmount).toList())'));
  expect(code,contains('expensePieSvg(chartSlices)'));
  expect(code,contains(r'pairedBarChartSvg(buckets.map((p)=>(pdfAmount(p.$1),pdfAmount(p.$2))).toList())'));
  expect(code,contains('row.key+1'));
  expect(code,contains("'رقم المعاملة'"));
  expect(code,contains("'No.'"));
 });

}

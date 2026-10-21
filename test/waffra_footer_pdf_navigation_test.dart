import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_footer.dart';
import 'package:waffra/waffra_pdf_reader.dart';

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
 testWidgets('The redesigned footer preserves five tabs and active position',(tester)async{
  await tester.binding.setSurfaceSize(const Size(393,852));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  var selected=0;
  await tester.pumpWidget(MaterialApp(home:StatefulBuilder(builder:(ctx,update)=>
   Scaffold(body:const SizedBox.expand(),
    bottomNavigationBar:WaffraFooterNavigation(
     selectedIndex:selected,english:false,
     onSelected:(next)=>update(()=>selected=next))))));
  expect(find.byKey(const Key('waffra-modern-footer')),findsOneWidget);
  for(var index=0;index<5;index++){
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
}

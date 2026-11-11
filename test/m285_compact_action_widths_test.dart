import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_action_layout.dart';
import 'package:waffra/waffra_practical_tools_page.dart';

void main() {
 test('M285 accessible shared actions keep compact 48dp taps and standard padding',(){
  expect(WaffraActionLayout.minimumSize.height,48);
  expect(WaffraActionLayout.contentPadding.horizontal,20);
  expect(WaffraActionLayout.contentPadding.vertical,16);
 });

 for(final english in <bool>[false,true]){
  for(final width in <double>[320,390]){
   testWidgets('M640 four read-only tools fit smaller layouts ${english?'EN':'AR'} $width',(tester)async{
    tester.view.physicalSize=Size(width,900);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
     home:Directionality(textDirection:english?TextDirection.ltr:TextDirection.rtl,
      child:WaffraPracticalToolsPage(english:english,entries:const [])),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('m281-health-tile')),findsOneWidget);
    expect(find.byKey(const Key('m281-search-tile')),findsOneWidget);
    expect(find.byKey(const Key('m281-month-tile')),findsOneWidget);
    expect(find.byKey(const Key('m281-diagnostics-tile')),findsOneWidget);
    expect(find.byKey(const Key('m281-receipt-tile')),findsNothing);
    expect(find.textContaining('Receipt OCR scanner'),findsNothing);
    expect(find.textContaining('قارئ الفواتير'),findsNothing);
    await tester.tap(find.byKey(const Key('m281-health-tile')));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
   });
  }
 }
}

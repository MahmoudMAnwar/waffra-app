import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smart_features.dart';

void main() {
 test('M671 tour removed from source, startup and settings; five-tab UI retained',(){
  final source=readWaffraMainSourceForContracts();
  final plan=File('lib/waffra_tour_plan.dart');
  expect(plan.existsSync(),isFalse);
  for(final retired in <String>[
   'WaffraTourPlan','tourActive','tourOverlay()', 'beginTour()',
   'Replay app tour','إعادة الجولة التعريفية',
   'waffra_in_app_tour_seen_v2', '_tourGlow', '_tourKeys',
   'WaffraTourShade', 'tourHeadingKey',
  ]){
   expect(source, isNot(contains(retired)),reason:'retired $retired');
  }
  expect(source,contains("waffraIsEnglish?'About Waffra':'عن وفرة'"));
  expect(source,contains('WaffraFooterNavigation.itemCount-1'));
  expect(source,contains('floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)'));
 });

 for(final english in <bool>[false,true]){
  for(final width in <double>[320,393,600]){
   testWidgets('M671 tools keep accessible heading without tour target english=$english width=$width',
    (tester)async {
    tester.view.physicalSize=Size(width,800);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:Directionality(
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     child:Scaffold(body:WaffraSmartFeaturesPage(
      embedded:true,english:english,
      entries:const [],goals:const [],recurring:const [])))));
    await tester.pumpAndSettle();
    expect(find.text(english?'Waffra smart tools':'أدوات وفرة الذكية'),findsWidgets);
    expect(tester.takeException(),isNull);
   });
  }
 }
}

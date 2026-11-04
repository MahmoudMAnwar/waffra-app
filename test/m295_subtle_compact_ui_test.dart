import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_subtle_selection.dart';

void main(){
 test('Selected options get a subtle distinguishable border, no thick halo',(){
  for(final brightness in [Brightness.light,Brightness.dark]){
   final theme=WaffraSubtleSelection.segmented(brightness);
   final active=theme.style!.side!.resolve({WidgetState.selected})!;
   final inactive=theme.style!.side!.resolve(<WidgetState>{})!;
   expect(active.width,1.6);
   expect(inactive.width,1.0);
   expect(active.color,isNot(inactive.color));
   expect(theme.style!.minimumSize!.resolve({})!.height,greaterThanOrEqualTo(48));
  }
 });
 for(final brightness in [Brightness.light,Brightness.dark]){
  testWidgets('Goals count is single-line at default scale in $brightness',(tester)async{
   tester.view.physicalSize=const Size(320,820);
   tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);
   addTearDown(tester.view.resetDevicePixelRatio);
   await tester.pumpWidget(MaterialApp(
    theme:ThemeData(brightness:brightness),
    home:const Directionality(textDirection:TextDirection.rtl,
     child:Scaffold(body:Center(child:SizedBox(width:174,
      child:WaffraOutlinedItemsCount(label:'عدد الأهداف الحالية',count:0)))))));
   await tester.pump();
   expect(find.byType(WaffraOutlinedItemsCount),findsOneWidget);
   final singleLine=find.descendant(
    of:find.byType(WaffraOutlinedItemsCount),
    matching:find.byWidgetPredicate((w)=>w is Text&&w.maxLines==1));
   expect(singleLine,findsWidgets);
   expect(tester.takeException(),isNull);
  });
 }
}

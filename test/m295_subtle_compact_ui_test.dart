import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_subtle_selection.dart';

void main(){
 test('Active borders are subtle, distinct, and 48dp accessible in light/dark',(){
  for(final brightness in [Brightness.light,Brightness.dark]){
   final style=WaffraSubtleSelection.segmented(brightness).style!;
   final active=style.side!.resolve({WidgetState.selected})!;
   final idle=style.side!.resolve(<WidgetState>{})!;
   expect(active.width,1.6);
   expect(idle.width,1.0);
   expect(active.color,isNot(idle.color));
   expect(style.minimumSize!.resolve({})!.height,greaterThanOrEqualTo(48));
  }
 });
}

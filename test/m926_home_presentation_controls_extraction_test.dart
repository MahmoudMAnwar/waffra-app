import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M926 original UI scroll/motion helpers registered without finance mutation',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_presentation_controls.part.dart').readAsStringSync();
  expect(main.split("part 'waffra_home_presentation_controls.part.dart';").length,2);
  expect(part,startsWith("part of 'main.dart';"));
  expect(main,isNot(contains(' void _handleDashboardScroll(){')));
  expect(main,isNot(contains(' Future<void> setAnimationLevel(String next)async {')));
  for(final t in [
   ' void _handleDashboardScroll(){',
   '_dashboardScrollController.offset>96',
   'WidgetsBinding.instance.addPostFrameCallback((_){',
   ' Future<void> setAnimationLevel(String next)async {',
   "if(!{'full','balanced','reduced','off'}.contains(next))return;",
   "p.setString('waffra_animation_level',next)",
  ]){expect(part,contains(t),reason:t);}
  expect(part,isNot(contains('WaffraFinanceRoute.')));
  expect(part,isNot(contains('saveCaptured(')));
 });
 test('M926 legacy source QA gets exact unchanged real production helper statements',(){
  final original=readWaffraMainSourceForContracts();
  final part=File('lib/waffra_home_presentation_controls.part.dart').readAsStringSync();
  final a=original.indexOf(' void _handleDashboardScroll(){');
  final b=original.indexOf(" String search='',typeFilter='الكل'",a);
  final code=part.substring(part.indexOf(' void _handleDashboardScroll(){'),part.lastIndexOf('\n}')+1);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(original.substring(a,b),code);
 });
}

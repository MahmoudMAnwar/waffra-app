import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('M258 safe-main finance refresh wiring all four pages',(){
  final main=File('lib/main.dart').readAsStringSync();
  final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(main,contains('onRefresh:()=>_refreshAndSettle(_dashboardScrollController,0)'));
  expect(main,contains('tab==1?_categoryScrollController:'));
  expect(main,contains('tab==3?_goalsScrollController:_recurringScrollController,tab'));
  expect(main,contains('controller:_goalsScrollController'));
  expect(main,contains('controller:_recurringScrollController'));
  expect(categories,contains('controller:_categoryScrollController'));
  expect(main,contains('isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null'));
  expect(main,contains('ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics())'));
 });
}

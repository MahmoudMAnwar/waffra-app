import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M258 all four finance tabs settle after verified refresh',(){
  final home=File('lib/main.dart').readAsStringSync();
  final categories=File('lib/waffra_categories_page.part.dart').readAsStringSync();
  expect(home,contains('onRefresh:()=>_refreshAndSettle(_dashboardScrollController,0)'));
  expect(home,contains('tab==1?_categoryScrollController:'));
  expect(home,contains('tab==2?_goalsScrollController:_recurringScrollController,tab'));
  expect(home,contains('controller:_goalsScrollController'));
  expect(home,contains('controller:_recurringScrollController'));
  expect(categories,contains('controller:_categoryScrollController'));
  expect(home,contains('isStillVisible:()=>mounted&&ready&&_financeLoadFailure==null'));
  expect(home,contains('ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics())'));
  expect(categories,contains('ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics())'));
 });
}

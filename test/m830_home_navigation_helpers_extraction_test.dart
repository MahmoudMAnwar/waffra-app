import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M830 Home navigation and user-approved FAB/back behavior retain registered code',(){
  final main=File('lib/main.dart').readAsStringSync();
  final part=File('lib/waffra_home_navigation_helpers.part.dart').readAsStringSync();
  expect(main,contains("part 'waffra_home_navigation_helpers.part.dart';"));
  expect(part,startsWith("part of 'main.dart';"));
  expect(part,contains('extension _WaffraHomeNavigationHelpers on _HomeScreenState'));
  for(final item in <String>[
   ' Widget categoriesPage()=>categoriesPageV2();',
   ' Widget _summaryBox(',
   ' Widget _filterChip(',
   ' Widget currentTab(){',
   ' Widget _currentTabContents(){',
   ' void _swipeBetweenSections(',
   ' Future<void> selectFooter(',
   ' bool _consumeHomeBack(){',
  ]) {
   expect(part,contains(item),reason:item);
  }
  expect(main,contains(' @override Widget build(BuildContext context)=>PopScope('));
  expect(part,isNot(contains('_financeAuthority.saveCaptured(')));
 });
 test('M830 original Home navigation source is reconstructed identically',(){
  final full=readWaffraMainSourceForContracts();
  final start=full.indexOf(' Widget categoriesPage()=>categoriesPageV2();');
  final end=full.indexOf(' @override Widget build(BuildContext context)=>PopScope(',start);
  final part=File('lib/waffra_home_navigation_helpers.part.dart').readAsStringSync();
  final original=part.substring(part.indexOf(' Widget categoriesPage()=>categoriesPageV2();'),
    part.lastIndexOf('\n}')+1);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  expect(full.substring(start,end),original);
 });
}

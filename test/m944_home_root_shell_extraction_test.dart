import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main() {
 test('M944 Home root composition lives in one registered State extension', () {
  final main = File('lib/main.dart').readAsStringSync();
  final shell = File('lib/waffra_home_root_shell.part.dart').readAsStringSync();
  expect(main, contains("part 'waffra_home_root_shell.part.dart';"));
  expect(main, contains(
    ' @override Widget build(BuildContext context)=>_m944BuildHome();'));
  expect(shell, startsWith("part of 'main.dart';"));
  expect(shell, contains(
    'extension _WaffraHomeRootShell on _HomeScreenState {'));
  expect(shell, contains(' Widget _m944BuildHome()=>PopScope('));
  expect(main, isNot(contains(
    ' @override Widget build(BuildContext context)=>PopScope(')));
  // Exactly one real FAB / Snackbar source; no duplicated Home tree.
  expect(shell.split('floatingActionButtonLocation:').length, 2);
  expect(shell.split("Key('m675-snackbar-beside-unchanged-fab')").length, 2);
  expect(shell, contains(
   'floatingActionButtonLocation:WaffraDirectionalFabLocation(english:waffraIsEnglish)'));
  expect(shell, contains(
   'floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
  expect(shell, contains('width:58,height:58'));
  expect(shell, contains("Key('waffra-fullscreen-fab-blur')"));
  expect(shell, contains(
    'if(accountOpened||tab==2||!ready)'));
  expect(shell, contains(
    'WaffraFooterNoticeHost(expandToAvailableWidth:true)'));
  expect(shell, contains('WaffraSmoothConfirmationOverlay('));
 });

 test('M944 relocated root still has verified startup gate and full back route', () {
  final shell = File('lib/waffra_home_root_shell.part.dart').readAsStringSync();
  final reconstructed = readWaffraMainSourceForContracts();
  expect(shell, contains(' Widget _m944BuildHome()=>PopScope('));
  expect(reconstructed, isNot(contains(
    ' @override Widget build(BuildContext context)=>_m944BuildHome();')));
  expect(shell, contains('child:!ready&&_financeLoadFailure==null?'));
  expect(shell, contains('const SizedBox.shrink():Stack(children:[Scaffold('));
  expect(shell, contains('body:_financeLoadFailure!=null?_financialRecoveryScreen():'));
  expect(shell, contains('child:currentTab()'));
  expect(shell, contains('if(!accountOpened&&ready&&tab!=2)'));
  expect(shell, contains(
   'floatingActionButton:!ready||accountOpened||tab==2?null:CompositedTransformTarget('));
  expect(shell, contains('onTap:WaffraHaptics.tapRequired('));
  expect(shell, contains('_fabOverlayAnchor'));
  expect(shell, contains('tab==0&&!accountOpened?Duration.zero:'));
  expect(shell, contains('onSelected:WaffraHaptics.selectionRequired('));
 });
}

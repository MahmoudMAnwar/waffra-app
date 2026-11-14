import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('M904 original Widget refresh is registered, authenticated and read only',(){
  final m=File('lib/main.dart').readAsStringSync();
  final p=File('lib/waffra_home_widget_balance.part.dart').readAsStringSync();
  expect(m.split("part 'waffra_home_widget_balance.part.dart';").length,2);
  expect(p,startsWith("part of 'main.dart';"));
  expect(m,isNot(contains(' Future<void> _refreshWidget()async{')));
  expect(m,isNot(contains(' Future<void> _publishVerifiedWidgetBalance(')));
  expect(p,contains('extension _WaffraHomeWidgetBalance on _HomeScreenState'));
  expect(p,contains('WaffraFinanceRoute.widgetBalanceRefresh'));
  expect(p,contains('verified.finance.requireIntegrity();'));
  expect(p,contains('WaffraAuthoritativeWidgetBalance.netHalalas'));
  expect(p,contains('WaffraLargeJsonDecode.isolateThreshold'));
  expect(p,contains('hideWaffraAmounts.value'));
  expect(p,contains("balance:'***',negative:false,hidden:true"));
  expect(p,isNot(contains('saveCaptured(')));
  expect(p,isNot(contains('commitConfirmedSms(')));
 });
 test('M904 strict source contract restores both actual methods byte-identically',(){
  final source=readWaffraMainSourceForContracts();
  final part=File('lib/waffra_home_widget_balance.part.dart').readAsStringSync();
  final a=source.indexOf(' Future<void> _refreshWidget()async{');
  final b=source.indexOf(' // M762: verified finance persistence',a);
  final expected=part.substring(part.indexOf(' Future<void> _refreshWidget()async{'),part.lastIndexOf('\n}')+1);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(source.substring(a,b),expected);
  expect(source.split(' Future<void> _refreshWidget()async{').length,2);
  expect(source.split(' Future<void> _publishVerifiedWidgetBalance(').length,2);
 });
}

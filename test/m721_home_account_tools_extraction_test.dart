import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('M721 registered account tools retain original backup and PIN flows',(){
  final home=File('lib/main.dart').readAsStringSync();
  final p=File('lib/waffra_home_account_tools.part.dart').readAsStringSync();
  expect(home,contains("part 'waffra_home_account_tools.part.dart';"));
  expect(p,startsWith("part of 'main.dart';"));
  expect(p,contains('extension _WaffraHomeAccountTools on _HomeScreenState'));
  expect(home,isNot(contains(' Future<void> backupDialog()async {')));
  expect(p,contains(' Future<void> backupDialog()async {'));
  expect(p,contains(' Future<void> configurePin()async {'));
  expect(p,contains(' Future<void> eraseFinancialData()async {'));
 });
 test('M721 real source reconstructs safe archive and account tools',(){
  final s=readWaffraMainSourceForContracts();
  final b=s.indexOf(' Future<void> backupDialog()');
  final e=s.indexOf(' Widget currentTab()',b);
  expect(b,greaterThan(0));
  expect(e,greaterThan(b));
  expect(s.substring(b,e),contains('_authorizeSensitiveAction'));
 });
}

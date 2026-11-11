import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main(){
 test('M636 external widget has no separate writable SMS/UI source',(){
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  expect(File('lib/waffra_widget_capture.part.dart').existsSync(),false);
  expect(native,contains('Intent(context, MainActivity::class.java)'));
  expect(native,contains('action = "waffra.ADD_TRANSACTION"'));
  expect(home,contains('if(!mounted||!ready||waffraWidgetAction.value!=\'add\')return;'));
  expect(home,contains('WidgetsBinding.instance.addPostFrameCallback'));
  expect(home,contains('unawaited(entrySheet())'));
 });
 test('M266 pending finance cutover still fails closed without data loss',()async{
  const original='[{"id":"synthetic-previous","amount":25}]';
  SharedPreferences.setMockInitialValues({
   'entries':original,
   'waffra_sms_hashes_v1':<String>['original-hash'],
   WaffraLiveLegacyFinanceGuard.pendingKey:true,
  });
  final prefs=await SharedPreferences.getInstance();
  await expectLater(const WaffraLiveLegacyFinanceGuard()
   .requireLegacySource(prefs),throwsA(isA<StateError>()));
  expect(prefs.getString('entries'),original);
  expect(prefs.getStringList('waffra_sms_hashes_v1'),['original-hash']);
 });
 test('M266 activated encrypted source never falls back to stale widget finance',()async{
  SharedPreferences.setMockInitialValues({
   WaffraLiveLegacyFinanceGuard.activeKey:true,
   'entries':'[{"id":"legacy"}]',
  });
  final prefs=await SharedPreferences.getInstance();
  await expectLater(const WaffraLiveLegacyFinanceGuard()
   .requireLegacySource(prefs),throwsA(isA<StateError>()));
  expect(prefs.getString('entries'),contains('legacy'));
 });
}

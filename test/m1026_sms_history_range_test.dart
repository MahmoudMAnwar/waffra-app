import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1026 all history requires an explicit verified account action',(){
  final profile=File('lib/waffra_home_profile.part.dart').readAsStringSync();
  expect(profile,contains('Scan all SMS history'));
  expect(profile,contains('فحص سجل الرسائل بالكامل'));
  expect(profile,contains('_scanAllBankSmsHistoryFromSettings()'));
  final manager=File('lib/waffra_home_sms_management.part.dart').readAsStringSync();
  expect(manager,contains('Future<void> _scanAllBankSmsHistoryFromSettings()async{'));
  expect(manager,contains('showWaffraDialog<bool>'));
  expect(manager,contains('if(confirmed!=true)return;'));
  expect(manager,contains('await WaffraAutoSms.enableAllHistoryScan()'));
  expect(manager,contains('_refreshAutoSmsInbox(importMonth:true)'));
 });
 test('M1026 native full-history flag is consent-bound and bounded by cursor',(){
  final store=File('native/WaffraAutoSmsStore.kt').readAsStringSync();
  expect(store,contains('private const val historyAllName'));
  expect(store,contains('fun enableAllHistoryScan(context: Context): Boolean'));
  expect(store,contains('if (!enabled(context)) return@synchronized false'));
  expect(store,contains('putBoolean(historyAllName, true)'));
  expect(store,contains('if (prefs.getBoolean(historyAllName, false)) return 1L'));
  expect(store,contains('if (queue.length() >= maxCandidates)'));
  expect(store,contains('.putLong(historyCursorAt, nextAt)'));
  expect(store,contains('.putLong(historyCursorId, nextId)'));
  expect(store,isNot(contains('.clear().apply()')));
  final native=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(native,contains('"enableAllSmsHistoryScan" ->'));
  expect(native,contains('smsHistoryExecutor.execute {'));
  final dart=File('lib/waffra_auto_sms.dart').readAsStringSync();
  expect(dart,contains("enableAllSmsHistoryScan"));
 });
}

import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_display_currency.dart';

void main(){
 test('M636 circular widget keeps verified balance without SMS entry',(){
  final workflow=File('.github/workflows/android.yml').readAsStringSync();
  final home=readWaffraMainSourceForContracts();
  final widget=File('native/WaffraWidget.kt').readAsStringSync();
  expect(workflow,contains('android:targetCellWidth="1"'));
  expect(workflow,contains('android:targetCellHeight="1"'));
  expect(home,contains('WaffraAuthoritativeWidgetBalance.netHalalas(raw)'));
  expect(home,contains('currency:WaffraDisplayCurrency.label(waffraIsEnglish)'));
  expect(widget,isNot(contains('WaffraQuickActivity::class.java')));
  expect(widget,contains('Intent(context, MainActivity::class.java)'));
  expect(widget,contains('action = "waffra.ADD_TRANSACTION"'));
  expect(widget,contains('PendingIntent.FLAG_IMMUTABLE'));
 });
 test('M225 widget currency presentation never multiplies stored SAR',(){
  final label=WaffraDisplayCurrency.displaySelection('EGP');
  expect(label.verified,isTrue);
  expect(label.fromSar(1000),1000);
  expect(label.toSar(1000),1000);
  final market=WaffraVerifiedDisplayQuote(
   code:'EGP',sarToSelected:12.5,
   updatedAtUtc:DateTime.utc(2026,10,25),provider:'test-only');
  expect(market.fromSar(100),1250);
 });
 test('M636 no standalone widget SMS review can bypass authentication',(){
  final home=readWaffraMainSourceForContracts();
  final native=File('native/WaffraMainActivity.kt').readAsStringSync();
  final workflow=File('.github/workflows/android.yml').readAsStringSync();
  expect(File('lib/waffra_widget_capture.part.dart').existsSync(),isFalse);
  expect(File('native/WaffraQuickActivity.kt').existsSync(),isFalse);
  expect(home,isNot(contains("defaultRouteName=='/waffra-widget'")));
  expect(home,contains('if(!mounted||!ready||waffraWidgetAction.value!=\'add\')return;'));
  expect(home,contains('unawaited(entrySheet())'));
  expect(native,contains('pendingWidgetAction = "add"'));
  expect(workflow,isNot(contains('<activity android:name="com.waffra.app.WaffraQuickActivity"')));
 });
}

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_auto_sms_consent.dart';

void main(){
 testWidgets('M417 consent explains Android permission prompts in order',
     (tester) async {
  await tester.pumpWidget(MaterialApp(home:WaffraAutoSmsConsentPage(
   english:true,onComplete:() async {})));
  expect(find.textContaining('SMS access to show financial messages'),findsOneWidget);
  expect(find.textContaining('notification permission'),findsOneWidget);
  expect(find.textContaining('decline either permission'),findsOneWidget);
  expect(find.byKey(const Key('m417-permission-skip')),findsNothing);
  expect(find.text('Allow SMS only'),findsNothing);
  expect(find.text('Allow SMS and automatic analysis'),findsNothing);
 });

 test('M417 permissions follow signup without unsolicited cloud consent',(){
  final src=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  expect(src,contains("await prefs.remove('waffra_cloud_sms_installation_consent_v2');"));
  expect(src,isNot(contains('WaffraSmsCloudService')));
  expect(src,contains('await WaffraAutoSms.optIn()'));
  expect(src,contains('await WaffraAutoSms.requestNotificationPermission()'));
  expect(src,contains('await widget.onComplete()'));
  expect(src.indexOf('await WaffraAutoSms.optIn()'),lessThan(
    src.indexOf('await widget.onComplete()')));
  expect(src,isNot(contains('allow(cloud:true)')));
 });
}

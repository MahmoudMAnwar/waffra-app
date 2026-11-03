import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_auto_sms_consent.dart';

void main() {
 testWidgets('M417 first launch can be skipped without SMS permissions',
     (tester) async {
  var finished=0;
  await tester.pumpWidget(MaterialApp(home:WaffraAutoSmsConsentPage(
   english:false,onComplete:()async{finished++;})));
  expect(find.byKey(const Key('m417-permission-skip')),findsOneWidget);
  expect(find.byKey(const Key('m417-permission-allow')),findsOneWidget);
  await tester.tap(find.byKey(const Key('m417-permission-skip')));
  await tester.pump();
  expect(finished,1);
 });
 testWidgets('M417 English copy explains on-device privacy',
     (tester) async {
  await tester.pumpWidget(MaterialApp(home:WaffraAutoSmsConsentPage(
   english:true,onComplete:()async{})));
  expect(find.textContaining('encrypted'),findsOneWidget);
  expect(find.text('Not now'),findsOneWidget);
 });
}

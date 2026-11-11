import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M639 permissions onboarding Arabic and English explain purpose, consent and no AI', () {
  final source=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  final start=source.indexOf("    Text(widget.english?'Waffra permissions':'أذونات وفرة',");
  final end=source.indexOf('    const SizedBox(height:20),',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final visible=source.substring(start,end);

  // Only user-visible localized labels in this permission page are checked;
  // security comments and the guarded opt-out must not be removed.
  expect(visible,contains('أذونات وفرة'));
  expect(visible,contains('هنطلب إذن الرسائل'));
  expect(visible,contains('العمليات المالية اللي تحتاج مراجعة'));
  expect(visible,contains('إذن الإشعارات'));
  expect(visible,contains('تقدر ترفض الأذونات أو تغيّرها لاحقًا'));
  expect(visible,contains('SMS access to show financial messages'));
  expect(visible,contains('notification permission for important alerts'));
  expect(visible,contains('You can decline either permission'));
  expect(
   RegExp(r'ذكاء\s*اصطناعي|سحابي|\bAI\b|artificial intelligence|\bcloud\b|\bmodel\b',
    caseSensitive:false).hasMatch(visible),
   isFalse,
  );
 });

 test('M639 updates visible strings only, preserving Android opt-in and retry', () {
  final source=File('lib/waffra_auto_sms_consent.dart').readAsStringSync();
  expect(source,contains('await WaffraSmsCloudService.setConsent(false);'));
  expect(source,contains('final smsAllowed=await WaffraAutoSms.optIn();'));
  expect(source,contains('if(!smsAllowed){'));
  expect(source,contains('await WaffraAutoSms.requestNotificationPermission();'));
  expect(source,contains('await widget.onComplete();'));
  expect(source,contains("'تعذر استكمال إعداد الأذونات. أعد المحاولة للمتابعة بأمان.'"));
  expect(source,contains("widget.english?'Retry':'إعادة المحاولة'"));
  expect(
   source.indexOf('await WaffraSmsCloudService.setConsent(false);'),
   lessThan(source.indexOf('await WaffraAutoSms.optIn();')),
  );
 });
}

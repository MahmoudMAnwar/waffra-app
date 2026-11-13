import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = readWaffraMainSourceForContracts();
  String between(String start, String end) {
    final a = source.indexOf(start);
    final b = source.indexOf(end, a);
    expect(a, greaterThanOrEqualTo(0));
    expect(b, greaterThan(a));
    return source.substring(a, b);
  }

  test('M636 reuses pending SMS/cloud without obsolete model reads', () {
    final state = between('bool protectRecentApps=true;',
        'String? _accountOpenSection;');
    expect(state, contains('_m528SmsEnabledFuture??=WaffraAutoSms.enabled()'));
    expect(state, contains(
        '_m528CloudConsentFuture??=WaffraSmsCloudService.hasConsent()'));
    final profile = between('Widget profilePage(){',
        'Widget _addMenuOption({');
    expect(profile, contains('future:_m528SmsEnabled()'));
    expect(profile, contains('future:_m528CloudConsent()'));
    expect(profile, isNot(contains('future:WaffraAutoSms.enabled()')));
    expect(profile,
        isNot(contains('future:WaffraSmsCloudService.hasConsent()')));
  });

  test('M528 refreshes state only after setting changes and profile entry', () {
    final profile = between('Widget profilePage(){',
        'Widget _addMenuOption({');
    expect(profile, contains('await WaffraAutoSms.disable()'));
    expect(profile, contains(
        '_m528SmsEnabledFuture=WaffraAutoSms.enabled()'));
    expect(profile, contains(
        'await WaffraSmsCloudService.setConsent(enabled)'));
    expect(profile, contains(
        '_m528CloudConsentFuture=WaffraSmsCloudService.hasConsent()'));

    final header = between(
        "key:const Key('waffra-header-account-entry'),",
        'borderRadius:BorderRadius.circular(30),');
    expect(header, contains('_m528SmsEnabledFuture=null'));
    expect(header, contains('_m528CloudConsentFuture=null'));

    final resume = between('void _m468OnResume(){',
        '@override void initState(){super.initState();WaffraBackNavigation');
    expect(resume, contains('if(accountOpened&&mounted)setState((){'));
    expect(resume, contains('_m528CloudConsentFuture=null'));

    // M665.6 retired the per-message AI/Not-financial popup entirely.
    // The actual consent toggle still invalidates its cached setting,
    // but no bank SMS review is allowed to silently change cloud consent.
    final review=between(' Future<void> _reviewAutoSmsCandidates({',
        ' void _receiveSharedSms(){');
    expect(source,isNot(contains('Future<void> _analyzeAmbiguousSmsOnDemand(')));
    expect(review,isNot(contains('WaffraSmsCloudService.setConsent(true)')));
    expect(review,isNot(contains('Optional AI review')));
    expect(review,isNot(contains('تحليل اختياري بالذكاء الاصطناعي')));
    expect(review,contains("Key('m595-review-single-exclude')"));
    expect(profile,contains('await WaffraSmsCloudService.setConsent(enabled)'));
    expect(resume,contains('_m528CloudConsentFuture=null'));
  });

  test('M636 removes model settings while retaining protected finance deletion',(){
    final profile=between('Widget profilePage(){','Widget _addMenuOption({');
    expect(profile,isNot(contains("AI model':'نموذج الذكاء الاصطناعي")));
    expect(profile,contains('Encrypted backup & restore'));
    expect(source,isNot(contains('deleteAiModel()')));
    expect(source,contains('Future<void> eraseFinancialData()async'));
    expect(source,contains('WaffraAutoSms.disable()'));
  });
}

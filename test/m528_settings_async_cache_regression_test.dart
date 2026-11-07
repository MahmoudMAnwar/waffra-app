import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/main.dart').readAsStringSync();
  String between(String start, String end) {
    final a = source.indexOf(start);
    final b = source.indexOf(end, a);
    expect(a, greaterThanOrEqualTo(0));
    expect(b, greaterThan(a));
    return source.substring(a, b);
  }

  test('M528 reuses pending async SMS/cloud/model reads per account view', () {
    final state = between('bool protectRecentApps=true;',
        'String? _accountOpenSection;');
    expect(state, contains('_m528SmsEnabledFuture??=WaffraAutoSms.enabled()'));
    expect(state, contains(
        '_m528CloudConsentFuture??=WaffraSmsCloudService.hasConsent()'));
    expect(state, contains('_m528ModelDiskRevision!=revision'));
    expect(state, contains(
        '_m528ModelDiskFuture=WaffraOnDeviceQwen.shared.downloadedOnDisk()'));
    final profile = between('Widget profilePage(){',
        'Widget _addMenuOption({');
    expect(profile, contains('future:_m528SmsEnabled()'));
    expect(profile, contains('future:_m528CloudConsent()'));
    expect(profile, contains('future:_m528ModelDiskStatus(revision)'));
    expect(profile, isNot(contains('future:WaffraAutoSms.enabled()')));
    expect(profile,
        isNot(contains('future:WaffraSmsCloudService.hasConsent()')));
    expect(profile, isNot(contains(
        'future:WaffraOnDeviceQwen.shared.downloadedOnDisk()')));
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
  });

  test('M528 maintains model deletion biometric safety and revision reload', () {
    final deletion = between('Future<void> deleteAiModel()async {',
        'Future<void> eraseFinancialData()async {');
    expect(deletion,
        contains('WaffraBiometrics.confirmAiModelRemoval('));
    expect(deletion, contains('if(!biometric)'));
    expect(deletion, contains('await model.deleteDownloadedModel()'));
    expect(deletion, contains('_m528ModelDiskRevision=null;'));
    expect(deletion, contains('_m528ModelDiskFuture=null;'));
    expect(deletion, isNot(contains('persist(')));
  });
}

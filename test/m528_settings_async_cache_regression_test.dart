import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// M690 — Preserve local SMS and finance checks after cloud UI retirement.
void main(){
 final source=readWaffraMainSourceForContracts();
 String between(String a,String b){
  final start=source.indexOf(a),end=source.indexOf(b,start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  return source.substring(start,end);
 }
 test('M690 settings keep SMS cache but remove AI/cloud analysis switch',(){
  final state=between('bool protectRecentApps=true;','String? _accountOpenSection;');
  expect(state,contains('_m528SmsEnabledFuture??=WaffraAutoSms.enabled()'));
  final profile=between('Widget profilePage(){','Widget _addMenuOption({');
  expect(profile,contains('future:_m528SmsEnabled()'));
  expect(profile,contains('await WaffraAutoSms.disable()'));
  expect(profile,contains('_m528SmsEnabledFuture=WaffraAutoSms.enabled()'));
  expect(profile,isNot(contains('future:_m528CloudConsent()')));
  expect(profile,isNot(contains('WaffraSmsCloudService.setConsent(enabled)')));
  expect(profile,isNot(contains('AI analysis of bank SMS (cloud)')));
  expect(profile,isNot(contains('OpenRouter')));
 });
 test('M690 refresh still updates local permission, no SMS AI popup',(){
  final header=between("key:const Key('waffra-header-account-entry'),",
   'borderRadius:BorderRadius.circular(30),');
  expect(header,contains('_m528SmsEnabledFuture=null'));
  final resume=between('void _m468OnResume(){',
   '@override void initState(){super.initState();WaffraBackNavigation');
  expect(resume,contains('if(accountOpened&&mounted)setState((){'));
  final review=between(' Future<void> _reviewAutoSmsCandidates({',
   ' void _receiveSharedSms(){');
  expect(review,contains("Key('m595-review-single-exclude')"));
  expect(review,isNot(contains('WaffraSmsCloudService.setConsent(true)')));
 });
 test('M690 secure data deletion and backup remain accessible',(){
  final profile=between('Widget profilePage(){','Widget _addMenuOption({');
  expect(profile,contains('Encrypted backup & restore'));
  expect(source,contains('Future<void> eraseFinancialData()async'));
  expect(source,contains('WaffraAutoSms.disable()'));
 });
}

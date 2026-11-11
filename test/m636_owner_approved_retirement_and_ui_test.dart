import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M636/#555: Owner-approved removal is permanent; finance and SMS safety
/// checks are positive behavior requirements, not stale Qwen-era screenshots.
void main(){
 final home=File('lib/main.dart').readAsStringSync();
 final smart=File('lib/waffra_smart_features.dart').readAsStringSync();
 final widget=File('native/WaffraWidget.kt').readAsStringSync();
 test('M636 no local Qwen runtime/dependency, model installer, or old widget engine',(){
  for(final file in [
   'lib/waffra_ondevice_qwen.dart','lib/waffra_ai_model_gate.dart',
   'lib/waffra_widget_capture.part.dart','native/WaffraQuickActivity.kt',
   'scripts/qa/prefetch_verified_llamadart.sh',
  ]){expect(File(file).existsSync(),false,reason:file);}
  expect(File('pubspec.yaml').readAsStringSync(),isNot(contains('llamadart:')));
  expect(home,isNot(contains('WaffraOnDeviceQwen')));
  expect(smart,isNot(contains('WaffraOnDeviceQwen')));
  expect(smart,isNot(contains('waffra-local-ai-opt-in')));
  expect(smart,isNot(contains("'اسأل وفرة'")));
 });
 test('M636 FAB blurs full background, retains global close and manual-only Home',(){
  expect(home,contains("Key('waffra-fullscreen-fab-blur')"));
  expect(home,contains('child:ClipRect(child:BackdropFilter('));
  expect(home,contains('ui.ImageFilter.blur(sigmaX:6,sigmaY:6)'));
  expect(home,contains('onTap:WaffraHaptics.tap(()=>setState(()=>addFabExpanded=false))'));
  expect(home,contains("label:waffraIsEnglish?'Add manual transaction':'إضافة عملية يدوية'"));
  expect(home,isNot(contains("label:waffraIsEnglish?'Bank message':'رسالة بنكية'")));
  expect(home,contains('unawaited(_launchAddAction(()=>entrySheet(),fromMenu:true))'));
 });
 test('M636 splash crosses into real sign-in without second forced timer',(){
  expect(home,contains('WaffraLaunchIntro(onFinished:_m632SplashCompleted)'));
  expect(home,contains('child:AnimatedSwitcher('));
  expect(home,contains('duration:waffraMotion(420)'));
  expect(home,contains('switchInCurve:Curves.easeOutCubic'));
  expect(home,contains('_m623RootContent(rootContext)'));
 });
 test('M636 normal logout avoids finance error UI, but error stays fail-closed',(){
  final start=home.indexOf(' Future<void> _m627CloseForLogout()async{');
  final end=home.indexOf(' void _m627AbortFailedLogout(){',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final first=home.substring(start,end);
  expect(first,contains('_m627ClosingSession=true'));
  expect(first,isNot(contains("'جارٍ إنهاء الجلسة بأمان. بياناتك المالية محمية.'")));
  expect(home,contains('void _m627AbortFailedLogout(){'));
  expect(home,contains('await closingHome._m627CloseForLogout();'));
 });
 test('M636 widget action is owner-verified, SMS source stays in separate Review',(){
  expect(widget,contains('Intent(context, MainActivity::class.java)'));
  expect(widget,contains('action = "waffra.ADD_TRANSACTION"'));
  expect(widget,isNot(contains('WaffraQuickActivity::class.java')));
  expect(home,contains('if(!mounted||!ready||waffraWidgetAction.value!=\'add\')return;'));
  expect(home,contains('unawaited(entrySheet())'));
  expect(home,contains('await entrySheet(sms:true,initialSms:body,reviewedSender:sender);'));
  expect(home,contains('await WaffraAutoSms.acknowledgeCommitted([id]);'));
  expect(home,contains('userConfirmed:true'));
 });
}

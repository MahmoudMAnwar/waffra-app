import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_external_media_session.dart';
import 'package:waffra/waffra_sms_sender_brand.dart';
void main(){
 test('M467 bounded native picker does not disable normal privacy lock',()async{
  final pending=Completer<void>();
  final future=WaffraExternalMediaSession.runPicker(()=>pending.future);
  expect(WaffraExternalMediaSession.trustedBackgroundTransition(
   AppLifecycleState.paused),isTrue);
  expect(WaffraExternalMediaSession.trustedBackgroundTransition(
   AppLifecycleState.detached),isFalse);
  pending.complete();await future;
  expect(WaffraExternalMediaSession.trustedBackgroundTransition(
   AppLifecycleState.paused),isFalse);
 });
 test('M467 only fixed public bank identifiers receive bank marks',(){
  expect(WaffraSmsSenderBrand.publicLogoUrl('AlinmaPay'),contains('alinma.com'));
  expect(WaffraSmsSenderBrand.publicLogoUrl('AlRajhiBank'),
   contains('alrajhibank.com.sa'));
  expect(WaffraSmsSenderBrand.publicLogoUrl('private-OTP-1234'),isNull);
 });
}

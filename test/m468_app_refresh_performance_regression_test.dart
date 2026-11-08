import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_external_media_session.dart';

void main(){
 test('M468 media resume is isolated from expensive background work',()async{
  final pending=Completer<void>();
  final task=WaffraExternalMediaSession.runPicker(()=>pending.future);
  expect(WaffraExternalMediaSession.shouldSkipResumeBackgroundWork,isTrue);
  expect(WaffraExternalMediaSession.trustedBackgroundTransition(
   AppLifecycleState.detached),isFalse);
  pending.complete();await task;
  expect(WaffraExternalMediaSession.shouldSkipResumeBackgroundWork,isTrue);
 });

 test('M468 Home refresh reduces duplicate account and SMS scans',(){
  final s=File('lib/main.dart').readAsStringSync();
  expect(s,contains('final active=_m468AccountReadInFlight;'));
  expect(s,contains('_m468AccountReadAgain=true;'));
  expect(s,contains("final contextView=chosen=='all'?null:await api.readAccountContext("));
  expect(s,contains('AppLifecycleListener(onResume:_m468OnResume)'));
  expect(s,contains('WaffraExternalMediaSession.shouldSkipResumeBackgroundWork'));
  expect(s,contains('importMonth:!_autoSmsHistoryComplete'));
  expect(s,contains('unawaited(_syncWidgetTransactions());'));
  final resume=s.split('void _m468OnResume(){')[1]
   .split('@override void initState()')[0];
  expect(resume,contains('unawaited(_refreshAutoSmsInbox());'));
  expect(resume,isNot(contains('importMonth:')));
  expect(s,isNot(contains(
   'onResume:(){unawaited(_syncWidgetTransactions());unawaited(_refreshAutoSmsInbox(importMonth:true));}')));
 });

 test('M468 no financial authority or history is discarded for faster UI',(){
  final s=File('lib/main.dart').readAsStringSync();
  expect(s,contains('await _financialWriteQueue.drain();'));
  expect(s,contains('view.requireIntegrity();'));
  expect(s,contains('WaffraFreshHomeCatalogRecovery.load('));
  expect(s,contains('await _financeAuthority.commitConfirmedManual('));
 });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

void main() {
  test('Android biometric result never reveals finance while inactive', () {
    expect(WaffraBiometricSessionGuard.canReveal(
      authenticated: true, inForeground: false), isFalse);
    expect(WaffraBiometricSessionGuard.canReveal(
      authenticated: true, inForeground: true), isTrue);
    expect(WaffraBiometricSessionGuard.canReveal(
      authenticated: false, inForeground: true), isFalse);
  });

  test('Biometric prompt success is deferred until resume, not discarded', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('bool _biometricVerifiedAwaitingResume=false;'));
    expect(source, contains('lifecycle==AppLifecycleState.inactive'));
    expect(source, contains('_biometricVerifiedAwaitingResume=true;'));
    expect(source, contains('if(_biometricVerifiedAwaitingResume){'));
    expect(source, contains('if(mounted&&locked&&profile!=null&&!showLogin){'));
    expect(source, contains('setState(()=>locked=false);'));
  });

  test('Real background transition invalidates verification; inactive alone does not relock', () {
    final source = File('lib/main.dart').readAsStringSync();
    // The outer idle overlay now enforces the 60s absence, not an immediate
    // Home lock that would destroy an open transaction or modal draft.
    final lifecycle = source.substring(
        source.indexOf(' @override void didChangeAppLifecycleState('),
        source.indexOf(' @override void dispose(){WaffraRegionalCopy.'));
    final overlay = File('lib/waffra_idle_biometric_overlay.dart').readAsStringSync();
    expect(lifecycle, contains('WaffraBiometricSessionGuard.mustLockOn(state)'));
    expect(lifecycle, contains('_biometricVerifiedAwaitingResume=false;'));
    expect(lifecycle, isNot(contains('setState(()=>locked=true);')));
    expect(source, contains('builder:(context,child)=>WaffraNoticeTapDismissArea('));
    expect(source, contains('child:WaffraIdleBiometricOverlay('));
    expect(overlay, contains('state==AppLifecycleState.hidden||'));
    expect(overlay, contains('state==AppLifecycleState.paused||'));
    expect(overlay, contains('state==AppLifecycleState.detached){'));
    expect(overlay, contains('_backgroundAt??=widget.now();'));
    expect(overlay, contains('widget.now().difference(began)>=widget.timeout'));
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.paused), isTrue);
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.inactive), isFalse);
  });
}

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
    expect(source, contains('state==AppLifecycleState.paused||'));
    expect(source, contains('state==AppLifecycleState.hidden||'));
    expect(source, contains('state==AppLifecycleState.detached){'));
    expect(source, contains('WaffraBiometricSessionGuard.mustLockOn(state)'));
    expect(source, contains('_biometricVerifiedAwaitingResume=false;'));
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.paused), isTrue);
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.inactive), isFalse);
  });
}

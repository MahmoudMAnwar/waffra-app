import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

void main() {
  test('M424: actual background locks, transient screenshot inactive does not', () {
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.inactive),
        isFalse, reason: 'Screenshot or OS overlay may transiently lose focus');
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      expect(WaffraBiometricSessionGuard.mustLockOn(state), isTrue,
          reason: 'Leaving the foreground must lock for $state');
    }
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.resumed),
        isFalse);
  });

  test('M424: old OS success cannot reveal finance while backgrounded', () {
    expect(WaffraBiometricSessionGuard.canReveal(
        authenticated: false, inForeground: true), isFalse);
    expect(WaffraBiometricSessionGuard.canReveal(
        authenticated: true, inForeground: false), isFalse);
    expect(WaffraBiometricSessionGuard.canReveal(
        authenticated: true, inForeground: true), isTrue);
  });

  testWidgets('M424: biometric failure stays locked; retry needs another prompt',
      (tester) async {
    var attempts = 0;
    var unlocked = 0;
    await tester.pumpWidget(MaterialApp(home: WaffraMandatoryBiometricGate(
      english: false,
      checkAvailable: () async => true,
      authenticate: () async { attempts++; return false; },
      onVerified: () => unlocked++,
      onSignOut: () async {},
    )));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(unlocked, 0);
    expect(find.textContaining('لم يكتمل التحقق'), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    expect(find.byKey(const Key('waffra-mandatory-biometric-retry')),
      findsOneWidget);
    await tester.tap(find.byKey(
        const Key('waffra-mandatory-biometric-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(unlocked, 0);
  });

  testWidgets('M424: successful biometric callback is the only unlock path',
      (tester) async {
    var checked = 0;
    var verified = 0;
    await tester.pumpWidget(MaterialApp(home: WaffraMandatoryBiometricGate(
      english: true,
      checkAvailable: () async { checked++; return true; },
      authenticate: () async => true,
      onVerified: () => verified++,
      onSignOut: () async {},
    )));
    await tester.pumpAndSettle();
    expect(checked, 1);
    expect(verified, 1);
  });

  testWidgets('M424: no enrolled biometrics fail closed without password',
      (tester) async {
    var attempted = 0;
    var unlocked = 0;
    await tester.pumpWidget(MaterialApp(home: WaffraMandatoryBiometricGate(
      english: true,
      checkAvailable: () async => false,
      authenticate: () async { attempted++; return true; },
      onVerified: () => unlocked++,
      onSignOut: () async {},
    )));
    await tester.pumpAndSettle();
    expect(attempted, 0);
    expect(unlocked, 0);
    expect(find.textContaining('Set up fingerprint'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('PIN'), findsNothing);
  });

  testWidgets('M424: sign-out remains available without unlocking funds',
      (tester) async {
    var signedOut = 0;
    var unlocked = 0;
    await tester.pumpWidget(MaterialApp(home: WaffraMandatoryBiometricGate(
      english: true,
      checkAvailable: () async => false,
      authenticate: () async => false,
      onVerified: () => unlocked++,
      onSignOut: () async { signedOut++; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const Key('waffra-mandatory-biometric-signout')));
    await tester.pumpAndSettle();
    expect(signedOut, 1);
    expect(unlocked, 0);
  });

  test('M424: home route no longer exposes optional PIN settings', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('locked?WaffraMandatoryBiometricGate('));
    expect(source, contains('if(freshSession)locked=true;'));
    expect(source, contains('locked=u!=null;'));
    expect(source, contains('WaffraBiometricSessionGuard.mustLockOn(state)'));
    expect(source, isNot(contains(
      'locked?PinLockScreen(pinHash:pinHash!')));
    final account = source.substring(source.indexOf(
      "_accountSection(waffraIsEnglish?'Security & privacy'"));
    final screenshot = account.substring(0,
      account.indexOf('SwitchListTile(secondary:const Icon(Icons.preview_outlined'));
    expect(screenshot, isNot(contains('PIN app lock')));
    expect(screenshot, isNot(contains('Change PIN')));
    expect(screenshot, isNot(contains('configurePin')));
    expect(screenshot, isNot(contains('changePin')));
    expect(source, isNot(contains(
      "away>=const Duration(seconds:30)")));
    expect(source, contains("if(mounted)setState((){profile=null;showLogin=true;locked=false;"));
  });
}
